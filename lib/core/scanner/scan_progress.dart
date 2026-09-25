import 'dart:isolate';

/// Discrete phases the UI can react to — e.g. showing "Indexing tags" vs
/// "Linking library" in the scan progress sheet.
enum ScanPhase { walkingDirectories, readingTags, linkingLibrary, complete, error }

class ScanProgress {
  final ScanPhase phase;
  final int filesFound;
  final int filesProcessed;
  final int tracksInserted;
  final int tracksSkipped;
  final String? currentPath;
  final String? errorMessage;

  const ScanProgress({
    required this.phase,
    this.filesFound = 0,
    this.filesProcessed = 0,
    this.tracksInserted = 0,
    this.tracksSkipped = 0,
    this.currentPath,
    this.errorMessage,
  });

  ScanProgress copyWith({
    ScanPhase? phase,
    int? filesFound,
    int? filesProcessed,
    int? tracksInserted,
    int? tracksSkipped,
    String? currentPath,
    String? errorMessage,
  }) {
    return ScanProgress(
      phase: phase ?? this.phase,
      filesFound: filesFound ?? this.filesFound,
      filesProcessed: filesProcessed ?? this.filesProcessed,
      tracksInserted: tracksInserted ?? this.tracksInserted,
      tracksSkipped: tracksSkipped ?? this.tracksSkipped,
      currentPath: currentPath ?? this.currentPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Payload sent from the UI isolate to spawn a scan. Every field must be
/// isolate-transferable — primitives, Strings, the primitive-only
/// [ScanConfig] (serialized to JSON), and the [SendPort] itself, which
/// Dart's isolate machinery is specifically able to copy across —
/// since Isolate.spawn otherwise copies rather than shares memory.
class ScanRequest {
  final List<String> rootPaths;
  final String isarDirectoryPath;
  final Map<String, dynamic> scanConfigJson;
  final SendPort replyPort;

  const ScanRequest({
    required this.rootPaths,
    required this.isarDirectoryPath,
    required this.scanConfigJson,
    required this.replyPort,
  });
}
