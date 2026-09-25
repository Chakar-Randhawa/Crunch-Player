enum StemType { vocals, instrumental, drums, bass, other }

class StemSeparationResult {
  final Map<StemType, String>
      stemFilePaths; // WAV files, one per separated stem
  final Duration processingTime;
  const StemSeparationResult(
      {required this.stemFilePaths, required this.processingTime});
}

enum StemSeparationPhase { decoding, running, mixing, complete, error }

class StemSeparationProgress {
  final StemSeparationPhase phase;
  final double fractionComplete; // 0..1, meaningful during `running`
  final String? errorMessage;

  const StemSeparationProgress({
    required this.phase,
    this.fractionComplete = 0.0,
    this.errorMessage,
  });
}

/// Describes the tensor contract the converted spleeter_2stem_unet.onnx
/// model actually has — verified by loading the real model in
/// onnxruntime and inspecting its input/output tensors directly, not
/// assumed. The model operates on magnitude spectrograms, not raw
/// waveform: StftProcessor (in this same module) handles the real
/// STFT/ISTFT and Wiener-mask reconstruction around it, using constants
/// (frame length, hop, kept frequency bins, mask power/epsilon) read
/// directly off the original TensorFlow graph during conversion.
class StemModelSpec {
  final String assetPath;
  final String inputTensorName;
  final List<String> outputTensorNames; // in the same order as [producedStems]
  final List<StemType> producedStems;
  final int expectedSampleRate;
  final int expectedChannels;

  const StemModelSpec({
    required this.assetPath,
    required this.inputTensorName,
    required this.outputTensorNames,
    required this.producedStems,
    this.expectedSampleRate = 44100,
    this.expectedChannels = 2,
  });

  /// The real, verified Deezer Spleeter 2-stem model (vocals +
  /// accompaniment), converted from their official pretrained checkpoint
  /// (github.com/deezer/spleeter, released under the MIT license) — no
  /// training involved. The conversion covers only the model's pure-CNN
  /// U-Net (Conv2D/BatchNorm/LeakyReLU/Sigmoid), since TensorFlow's
  /// STFT/IRFFT ops don't convert cleanly to ONNX; StftProcessor
  /// reproduces the surrounding STFT → mask → ISTFT pipeline in Dart to
  /// match, using constants read directly from the original graph.
  static const spleeter2Stem = StemModelSpec(
    assetPath: 'assets/models/spleeter_2stem_unet.onnx',
    inputTensorName: 'strided_slice_3:0',
    outputTensorNames: [
      'vocals_spectrogram/mul:0',
      'accompaniment_spectrogram/mul:0'
    ],
    producedStems: [StemType.vocals, StemType.instrumental],
  );
}
