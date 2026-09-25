import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class InstantDemuxResult {
  final String outputPath;
  final String mimeType;
  final Duration duration;
  const InstantDemuxResult(
      {required this.outputPath,
      required this.mimeType,
      required this.duration});
}

/// The MP4→MP3 Demuxer feature's Dart entry point. Offers two genuinely
/// different operations rather than pretending they're the same thing
/// wearing different labels:
///
/// - [extractInstant]: a millisecond-scale stream copy of the video's
///   existing audio track — real "instant" extraction, but the output
///   format matches whatever the source used (almost always AAC/.m4a,
///   not a literal MP3 bitstream).
/// - [transcodeToMp3]: decodes to PCM and re-encodes through a real MP3
///   encoder (LAME via JNI). This produces an actual .mp3 file, takes
///   time proportional to the track length (not instant), and requires
///   the native encoder to have been built — see DemuxPlugin.kt's error
///   message for setup steps if [isMp3EncoderAvailable] returns false.
class VideoAudioExtractor {
  static const MethodChannel _channel =
      MethodChannel('com.craunch.player/demux');

  const VideoAudioExtractor();

  bool get isSupportedPlatform => Platform.isAndroid;

  Future<InstantDemuxResult> extractInstant(String videoPath) async {
    _assertSupported();
    final outputPath = await _outputPathFor(videoPath, extension: 'm4a');

    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('extractInstant', {
      'inputPath': videoPath,
      'outputPath': outputPath,
    });
    if (result == null)
      throw StateError('Native demux returned no result for $videoPath');

    return InstantDemuxResult(
      outputPath: result['outputPath'] as String,
      mimeType: result['mimeType'] as String,
      duration: Duration(microseconds: (result['durationUs'] as num).toInt()),
    );
  }

  Future<bool> isMp3EncoderAvailable() async {
    if (!isSupportedPlatform) return false;
    return await _channel.invokeMethod<bool>('isMp3EncoderAvailable') ?? false;
  }

  /// Throws a [PlatformException] with code `ENCODER_NOT_BUILT` and a
  /// setup-instructions message if the native LAME bridge hasn't been
  /// compiled in yet — see the class doc above.
  Future<String> transcodeToMp3(String videoPath,
      {int bitrateKbps = 192}) async {
    _assertSupported();
    final outputPath = await _outputPathFor(videoPath, extension: 'mp3');

    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('transcodeToMp3', {
      'inputPath': videoPath,
      'outputPath': outputPath,
      'bitrateKbps': bitrateKbps,
    });
    if (result == null)
      throw StateError('Native transcode returned no result for $videoPath');
    return result['outputPath'] as String;
  }

  Future<String> _outputPathFor(String sourcePath,
      {required String extension}) async {
    final dir = await getApplicationDocumentsDirectory();
    final base = p.basenameWithoutExtension(sourcePath);
    final outputDir = Directory(p.join(dir.path, 'extracted_audio'));
    await outputDir.create(recursive: true);
    return p.join(outputDir.path, '$base.$extension');
  }

  void _assertSupported() {
    if (!isSupportedPlatform) {
      throw UnsupportedError(
        'Video audio extraction is currently implemented for Android only '
        '(MediaExtractor/MediaMuxer + the LAME JNI bridge). An iOS equivalent '
        'using AVAssetReader/AVAssetWriter for the instant path, and the same '
        'vendored-encoder requirement for true MP3 output, is a documented, '
        'not-yet-built parallel.',
      );
    }
  }
}
