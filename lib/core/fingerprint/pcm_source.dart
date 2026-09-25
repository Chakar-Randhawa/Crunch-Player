import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../stems/pcm_decoder_channel.dart';
import '../stems/wav_pcm_codec.dart';

/// Thin convenience wrapper combining the native PCM decoder with the WAV
/// reader and a channel downmix — separated out from
/// StemSeparationEngine so the fingerprinter doesn't need to depend on
/// the stems module's ONNX-specific machinery for what is, for its
/// purposes, just "give me mono float samples".
class PcmSource {
  final PcmDecoderChannel _decoder;
  final WavPcmCodec _wavCodec;

  const PcmSource({
    PcmDecoderChannel decoder = const PcmDecoderChannel(),
    WavPcmCodec wavCodec = const WavPcmCodec(),
  })  : _decoder = decoder,
        _wavCodec = wavCodec;

  Future<Float64List> decodeToMonoFloat(String audioFilePath) async {
    final tempDir = await getTemporaryDirectory();
    final pcmPath = p.join(tempDir.path, '${p.basenameWithoutExtension(audioFilePath)}_fp.wav');

    await _decoder.decodeToPcm(audioFilePath, pcmPath);
    final pcm = await _wavCodec.read(pcmPath);

    await File(pcmPath).delete().catchError((_) => File(pcmPath));

    if (pcm.channelCount == 1) {
      return Float64List.fromList(pcm.samples.map((s) => s.toDouble()).toList());
    }

    // Downmix to mono by averaging channels — fingerprint matching only
    // needs the audio's spectral content, not stereo imaging.
    final frameCount = pcm.samples.length ~/ pcm.channelCount;
    final mono = Float64List(frameCount);
    for (int i = 0; i < frameCount; i++) {
      double sum = 0;
      for (int c = 0; c < pcm.channelCount; c++) {
        sum += pcm.samples[i * pcm.channelCount + c];
      }
      mono[i] = sum / pcm.channelCount;
    }
    return mono;
  }
}
