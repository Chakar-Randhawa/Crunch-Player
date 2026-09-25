import 'dart:convert';
import 'package:http/http.dart' as http;

/// A real client for AcoustID's public lookup service
/// (https://acoustid.org/webservice) — the HTTP call itself is correct
/// and complete. What it cannot do without two externally-supplied
/// pieces:
///
/// 1. **A Chromaprint-format fingerprint.** AudioFingerprinter in this
///    module produces a fingerprint that's real and useful for local
///    duplicate detection, but it is not bit-compatible with what
///    AcoustID's server expects — that requires actually running
///    libchromaprint (BSD-licensed, from acoustid.org), which means a
///    JNI bridge analogous to lame_jni.cpp for the MP3 encoder. Not
///    built here.
/// 2. **An API key.** Free to register at https://acoustid.org/new-application,
///    but it's a per-application credential this code cannot generate on
///    your behalf.
///
/// This class exists so the integration shape is documented and ready —
/// once both pieces above exist, [lookup] is the actual, correct call to
/// make.
class AcoustIdClient {
  final String apiKey;
  const AcoustIdClient({required this.apiKey});

  static const _endpoint = 'https://api.acoustid.org/v2/lookup';

  /// [chromaprintFingerprint] must be the compressed base64 string a real
  /// libchromaprint `chromaprint_get_fingerprint` call produces — passing
  /// this app's own AudioFingerprinter output here will not return
  /// meaningful matches, since the server is comparing against a
  /// different, incompatible fingerprint format.
  Future<Map<String, dynamic>?> lookup({
    required String chromaprintFingerprint,
    required int durationSeconds,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'AcoustIdClient requires a real API key from '
        'https://acoustid.org/new-application — none was supplied.',
      );
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'client': apiKey,
      'duration': durationSeconds.toString(),
      'fingerprint': chromaprintFingerprint,
      'meta': 'recordings+releasegroups+compress',
      'format': 'json',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('AcoustID lookup failed: HTTP ${response.statusCode}');
    }

    // Intentionally returned as a raw decoded map rather than a typed
    // model — AcoustID's response shape (nested recordings/releasegroups)
    // is rich enough that a full typed model belongs in its own file once
    // this integration is actually wired up end to end, not sketched
    // ahead of the fingerprint format it depends on.
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
