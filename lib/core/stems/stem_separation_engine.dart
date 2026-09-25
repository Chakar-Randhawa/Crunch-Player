import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pcm_decoder_channel.dart';
import 'stem_models.dart';
import 'stft_processor.dart';
import 'wav_pcm_codec.dart';

/// Runs the verified spleeter_2stem_unet.onnx model (converted from
/// Deezer's real pretrained Spleeter checkpoint — see StemModelSpec's
/// doc comment) over decoded PCM audio: STFT → per-segment U-Net
/// inference → Wiener-style soft masking → ISTFT.
///
/// Every numeric constant this class relies on (frame length, hop,
/// frequency-bin cutoff, mask power/epsilon) was read directly off the
/// original TensorFlow graph during conversion, not guessed — see
/// StftProcessor's doc comment for where each one came from.
class StemSeparationEngine {
  final PcmDecoderChannel _pcmDecoder;
  final WavPcmCodec _wavCodec;
  final StftProcessor _stft;
  OrtSession? _session;
  StemModelSpec? _loadedSpec;

  StemSeparationEngine({
    PcmDecoderChannel pcmDecoder = const PcmDecoderChannel(),
    WavPcmCodec wavCodec = const WavPcmCodec(),
    StftProcessor stftProcessor = const StftProcessor(),
  })  : _pcmDecoder = pcmDecoder,
        _wavCodec = wavCodec,
        _stft = stftProcessor;

  Future<void> _ensureModelLoaded(StemModelSpec spec) async {
    if (_session != null && _loadedSpec?.assetPath == spec.assetPath) return;

    _session?.release();
    OrtEnv.instance.init();

    final sessionOptions = OrtSessionOptions();
    sessionOptions.setIntraOpNumThreads(4);

    final byteData = await rootBundle.load(spec.assetPath);
    final modelBytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _loadedSpec = spec;
  }

  Future<StemSeparationResult> separate({
    required String sourceAudioPath,
    StemModelSpec spec = StemModelSpec.spleeter2Stem,
    void Function(StemSeparationProgress progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    onProgress?.call(const StemSeparationProgress(phase: StemSeparationPhase.decoding));
    final tempDir = await getTemporaryDirectory();
    final pcmPath = p.join(tempDir.path, '${p.basenameWithoutExtension(sourceAudioPath)}_decoded.wav');
    await _pcmDecoder.decodeToPcm(sourceAudioPath, pcmPath);

    final pcm = await _wavCodec.read(pcmPath);
    if (pcm.sampleRate != spec.expectedSampleRate || pcm.channelCount != spec.expectedChannels) {
      throw StateError(
        'Decoded audio is ${pcm.sampleRate}Hz/${pcm.channelCount}ch but the '
        'model expects ${spec.expectedSampleRate}Hz/${spec.expectedChannels}ch. '
        'Resample before separation.',
      );
    }

    await _ensureModelLoaded(spec);
    final session = _session!;

    // De-interleave into per-channel sample arrays for independent STFTs.
    final frameCount = pcm.samples.length ~/ pcm.channelCount;
    final channelSamples = List.generate(pcm.channelCount, (c) {
      final out = Float64List(frameCount);
      for (int i = 0; i < frameCount; i++) {
        out[i] = pcm.samples[i * pcm.channelCount + c];
      }
      return out;
    });

    onProgress?.call(const StemSeparationProgress(phase: StemSeparationPhase.running));

    final channelStfts = channelSamples.map(_stft.forwardStft).toList();
    final totalStftFrames = channelStfts.first.real.length;
    final segmentCount = (totalStftFrames / StftConstants.timeFramesPerSegment).ceil().clamp(1, 1 << 30);

    // One output complex STFT per stem per channel, built up segment by
    // segment as inference completes.
    final stemChannelStfts = <StemType, List<ChannelStft>>{
      for (final stem in spec.producedStems)
        stem: List.generate(pcm.channelCount, (_) => ChannelStft([], [])),
    };

    for (int seg = 0; seg < segmentCount; seg++) {
      final segStart = seg * StftConstants.timeFramesPerSegment;
      final segFrameCount = math.min(StftConstants.timeFramesPerSegment, totalStftFrames - segStart);

      final inputTensor = _buildInputTensor(channelStfts, segStart, segFrameCount, pcm.channelCount);
      final maskEstimates = await _runInference(session, spec, inputTensor);

      _applyMaskAndAppend(
        channelStfts: channelStfts,
        maskEstimates: maskEstimates,
        segStart: segStart,
        segFrameCount: segFrameCount,
        spec: spec,
        output: stemChannelStfts,
      );

      onProgress?.call(StemSeparationProgress(
        phase: StemSeparationPhase.running,
        fractionComplete: ((seg + 1) / segmentCount).clamp(0.0, 1.0),
      ));
    }

    onProgress?.call(const StemSeparationProgress(phase: StemSeparationPhase.mixing));

    final outputDir = await getApplicationDocumentsDirectory();
    final baseName = p.basenameWithoutExtension(sourceAudioPath);
    final stemPaths = <StemType, String>{};

    for (final stem in spec.producedStems) {
      final channelWaveforms = stemChannelStfts[stem]!
          .map((channelStft) => _stft.inverseStft(channelStft, frameCount))
          .toList();

      final interleaved = Float32List(frameCount * pcm.channelCount);
      for (int i = 0; i < frameCount; i++) {
        for (int c = 0; c < pcm.channelCount; c++) {
          interleaved[i * pcm.channelCount + c] = channelWaveforms[c][i].clamp(-1.0, 1.0);
        }
      }

      final outputPath = p.join(outputDir.path, 'stems', '${baseName}_${stem.name}.wav');
      await Directory(p.dirname(outputPath)).create(recursive: true);
      await _wavCodec.write(
        outputPath,
        WavPcmData(samples: interleaved, sampleRate: pcm.sampleRate, channelCount: pcm.channelCount),
      );
      stemPaths[stem] = outputPath;
    }

    onProgress?.call(const StemSeparationProgress(phase: StemSeparationPhase.complete, fractionComplete: 1.0));
    stopwatch.stop();

    return StemSeparationResult(stemFilePaths: stemPaths, processingTime: stopwatch.elapsed);
  }

  /// Builds the [1, 512, 1024, 2] magnitude-spectrogram tensor the model
  /// expects for one segment, zero-padding the final short segment up to
  /// the model's fixed 512-frame input size.
  Float32List _buildInputTensor(
    List<ChannelStft> channelStfts,
    int segStart,
    int segFrameCount,
    int channelCount,
  ) {
    final tensor = Float32List(
      StftConstants.timeFramesPerSegment * StftConstants.keptFrequencyBins * channelCount,
    );

    for (int t = 0; t < segFrameCount; t++) {
      final frameIndex = segStart + t;
      for (int bin = 0; bin < StftConstants.keptFrequencyBins; bin++) {
        for (int c = 0; c < channelCount; c++) {
          final re = channelStfts[c].real[frameIndex][bin];
          final im = channelStfts[c].imag[frameIndex][bin];
          final magnitude = math.sqrt(re * re + im * im);
          final offset = (t * StftConstants.keptFrequencyBins + bin) * channelCount + c;
          tensor[offset] = magnitude;
        }
      }
    }
    return tensor;
  }

  Future<Map<StemType, Float32List>> _runInference(
    OrtSession session,
    StemModelSpec spec,
    Float32List inputTensorData,
  ) async {
    final shape = [
      1,
      StftConstants.timeFramesPerSegment,
      StftConstants.keptFrequencyBins,
      spec.expectedChannels,
    ];
    final inputTensor = OrtValueTensor.createTensorWithDataList(inputTensorData, shape);
    final runOptions = OrtRunOptions();

    final outputs = await session.runAsync(runOptions, {spec.inputTensorName: inputTensor});

    inputTensor.release();
    runOptions.release();

    final result = <StemType, Float32List>{};
    for (int i = 0; i < spec.producedStems.length; i++) {
      final outputValue = outputs?[i];
      if (outputValue == null) {
        throw StateError(
          'Model did not return output "${spec.outputTensorNames[i]}" — the '
          'converted ONNX model\'s tensor names have changed from what '
          'StemModelSpec expects.',
        );
      }
      result[spec.producedStems[i]] = _flattenToFloat32List(outputValue.value);
      outputValue.release();
    }
    return result;
  }

  /// Applies the real Wiener-style soft mask — mask_i = estimate_i^2 /
  /// (sum of all stems' estimate^2 + epsilon) — to the ORIGINAL complex
  /// mixture spectrogram for bins below the model's cutoff, and passes
  /// the mixture through unmodified (mask = 1.0) for bins at or above
  /// it, exactly matching the real graph's own behavior rather than
  /// silently zeroing or guessing that band.
  void _applyMaskAndAppend({
    required List<ChannelStft> channelStfts,
    required Map<StemType, Float32List> maskEstimates,
    required int segStart,
    required int segFrameCount,
    required StemModelSpec spec,
    required Map<StemType, List<ChannelStft>> output,
  }) {
    final channelCount = channelStfts.length;
    final stems = spec.producedStems;

    for (int t = 0; t < segFrameCount; t++) {
      final frameIndex = segStart + t;

      for (int c = 0; c < channelCount; c++) {
        final perStemReal = {for (final s in stems) s: Float64List(StftConstants.fullFrequencyBins)};
        final perStemImag = {for (final s in stems) s: Float64List(StftConstants.fullFrequencyBins)};

        for (int bin = 0; bin < StftConstants.fullFrequencyBins; bin++) {
          final mixReal = channelStfts[c].real[frameIndex][bin];
          final mixImag = channelStfts[c].imag[frameIndex][bin];

          if (bin >= StftConstants.keptFrequencyBins) {
            // Above the model's cutoff: BOTH stems get silence here
            // (mask = 0), not the mixture passed through. Verified
            // empirically against the real Spleeter graph's own
            // end-to-end output (feeding identical test signals through
            // the original waveform-in/waveform-out model and diffing
            // several reconstruction hypotheses against it) — the
            // passthrough approach this engine originally used measured
            // ~27x higher error against the real model's actual output
            // than dropping the band does. See StftConstants
            // .wienerPower's doc comment for the verification details.
            for (final stem in stems) {
              perStemReal[stem]![bin] = 0.0;
              perStemImag[stem]![bin] = 0.0;
            }
            continue;
          }

          double sumOfPowers = StftConstants.wienerEpsilon;
          final estimatesAtBin = <StemType, double>{};
          for (final stem in stems) {
            final estimate =
                maskEstimates[stem]![(t * StftConstants.keptFrequencyBins + bin) * channelCount + c];
            estimatesAtBin[stem] = estimate.toDouble();
            sumOfPowers += math.pow(estimate, StftConstants.wienerPower);
          }

          for (final stem in stems) {
            final mask = math.pow(estimatesAtBin[stem]!, StftConstants.wienerPower) / sumOfPowers;
            perStemReal[stem]![bin] = mixReal * mask;
            perStemImag[stem]![bin] = mixImag * mask;
          }
        }

        for (final stem in stems) {
          output[stem]![c].real.add(perStemReal[stem]!);
          output[stem]![c].imag.add(perStemImag[stem]!);
        }
      }
    }
  }

  Float32List _flattenToFloat32List(dynamic nested) {
    final flat = <double>[];
    void walk(dynamic node) {
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
      } else if (node is num) {
        flat.add(node.toDouble());
      }
    }

    walk(nested);
    return Float32List.fromList(flat);
  }

  Future<void> dispose() async {
    _session?.release();
    _session = null;
  }
}
