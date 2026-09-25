import 'dart:io';
import 'package:flutter/services.dart';

class PcmDecodeResult {
  final String pcmFilePath;
  final int sampleRate;
  final int channelCount;
  final int totalFrames;

  const PcmDecodeResult({
    required this.pcmFilePath,
    required this.sampleRate,
    required this.channelCount,
    required this.totalFrames,
  });
}

/// Wraps the native decode-to-PCM-WAV channel. Both the stem separator and
/// (indirectly, via a shared decode step) the MP4→MP3 demuxer's transcode
/// path use this rather than each maintaining their own MediaCodec logic.
class PcmDecoderChannel {
  static const MethodChannel _channel =
      MethodChannel('com.craunch.player/pcmdecoder');

  const PcmDecoderChannel();

  Future<PcmDecodeResult> decodeToPcm(
      String inputPath, String outputPath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'PCM decode is currently implemented for Android only (MediaExtractor + '
        'MediaCodec). An iOS equivalent using AVAssetReader follows the same '
        'contract and is a documented, not-yet-built parallel — see the module '
        'README note on iOS stem separation / MP3 transcoding.',
      );
    }

    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('decodeToPcm', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });

    if (result == null) {
      throw StateError('Native PCM decoder returned no result for $inputPath');
    }

    return PcmDecodeResult(
      pcmFilePath: result['pcmFilePath'] as String,
      sampleRate: result['sampleRate'] as int,
      channelCount: result['channelCount'] as int,
      totalFrames: (result['totalFrames'] as num).toInt(),
    );
  }
}
