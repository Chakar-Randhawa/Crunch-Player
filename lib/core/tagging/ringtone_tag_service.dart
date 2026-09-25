import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../tagging/id3_tag_writer.dart';

class RingtoneResult {
  final String uri;
  final bool autoApplied; // true if set as the actual default ringtone; false if only added to the picker
  const RingtoneResult({required this.uri, required this.autoApplied});
}

/// Combines the pure-Dart [Id3TagWriter] (tag editing needs no native
/// code — it's file I/O) with the native ringtone-setting channel.
///
/// **iOS note:** there is deliberately no iOS implementation here. Apple
/// does not expose a public API for a third-party app to set the
/// system's default ringtone — the only sanctioned paths are syncing a
/// specially-encoded .m4r file through Finder/iTunes, or the user
/// manually doing it through GarageBand's "Use as Ringtone" export,
/// neither of which this app can trigger programmatically. This is a
/// platform policy restriction, not a missing implementation — there is
/// no vendoring or native bridge that unlocks it, unlike the LAME/ONNX/
/// AVAudioEngine gaps elsewhere in this app.
class RingtoneTagService {
  static const MethodChannel _channel = MethodChannel('com.craunch.player/ringtone');
  final Id3TagWriter _tagWriter;

  const RingtoneTagService({Id3TagWriter tagWriter = const Id3TagWriter()}) : _tagWriter = tagWriter;

  Future<void> editTags(String mp3FilePath, TagEditFields fields) async {
    if (p.extension(mp3FilePath).toLowerCase() != '.mp3') {
      throw UnsupportedError(
        'Tag writing currently supports MP3 (ID3v2) only — see Id3TagWriter\'s '
        'doc comment for the M4A/FLAC scope note.',
      );
    }
    await _tagWriter.writeTags(mp3FilePath, fields);
  }

  bool get isRingtoneSupportedPlatform => Platform.isAndroid;

  Future<bool> canAutoApplyRingtone() async {
    if (!isRingtoneSupportedPlatform) return false;
    return await _channel.invokeMethod<bool>('canWriteSystemSettings') ?? false;
  }

  Future<void> openRingtonePermissionSettings() async {
    if (!isRingtoneSupportedPlatform) return;
    await _channel.invokeMethod('openWriteSettingsPermissionScreen');
  }

  Future<RingtoneResult> setAsRingtone(String sourceFilePath) async {
    if (!isRingtoneSupportedPlatform) {
      throw UnsupportedError(
        'Setting a system default ringtone programmatically is not possible on '
        'iOS — see RingtoneTagService\'s class doc for why this is a platform '
        'policy restriction rather than a missing feature.',
      );
    }

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('setAsRingtone', {
      'sourceFilePath': sourceFilePath,
      'displayName': p.basename(sourceFilePath),
    });
    if (result == null) throw StateError('Native ringtone setter returned no result');

    return RingtoneResult(
      uri: result['uri'] as String,
      autoApplied: result['autoApplied'] as bool,
    );
  }
}
