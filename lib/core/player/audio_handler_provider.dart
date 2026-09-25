import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'craunch_audio_handler.dart';

/// Overridden in main() with the real instance returned by
/// AudioService.init(), so UI code can reach the handler via
/// `ref.read(audioHandlerProvider)` without a global singleton variable.
final audioHandlerProvider = Provider<CraunchAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main() after AudioService.init().');
});
