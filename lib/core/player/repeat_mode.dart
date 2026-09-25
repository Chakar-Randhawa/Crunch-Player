/// Mirrors audio_service's AudioServiceRepeatMode but kept as a local type
/// so the queue/engine layer doesn't depend on audio_service directly —
/// only craunch_audio_handler.dart, at the boundary, translates between
/// the two.
enum CraunchRepeatMode { off, repeatOne, repeatAll }
