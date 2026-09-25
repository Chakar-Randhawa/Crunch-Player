/// Tunable parameters for the storage scanner. Kept as a plain immutable
/// value class (not a singleton/global) so it can be constructed fresh per
/// scan run and safely passed across the isolate boundary — every field
/// must stay isolate-transferable (primitives, Strings, Lists of those).
class ScanConfig {
  /// Extensions the scanner will index, without the leading dot, lowercase.
  final Set<String> allowedExtensions;

  /// Files shorter than this are skipped entirely — this is what filters
  /// out WhatsApp/Telegram voice notes and other short recordings that
  /// technically match an allowed extension but aren't music.
  final Duration minTrackDuration;

  /// Files below this size are skipped before duration is even checked,
  /// since a file this small cannot contain minTrackDuration of audio at
  /// any reasonable bitrate — avoids opening every tiny file's header.
  final int minFileSizeBytes;

  /// Directory names the scanner will never descend into, matched
  /// case-insensitively against the last path segment. Covers common
  /// non-music and system/cache directories.
  final Set<String> excludedDirectoryNames;

  /// Absolute directory paths (beyond excludedDirectoryNames) the user has
  /// explicitly opted out of, sourced from Folder.isExcluded rows.
  final Set<String> excludedAbsolutePaths;

  /// Maximum directory recursion depth from a scan root, as a safety cap
  /// against pathological symlink loops or extremely deep trees.
  final int maxRecursionDepth;

  /// Number of parsed tracks buffered before a batch is flushed to Isar,
  /// balancing write-transaction overhead against isolate memory growth
  /// on very large libraries.
  final int dbWriteBatchSize;

  const ScanConfig({
    this.allowedExtensions = const {'mp3', 'm4a', 'wav', 'flac', 'ogg', 'aac'},
    this.minTrackDuration = const Duration(seconds: 12),
    this.minFileSizeBytes = 64 * 1024, // 64 KB
    this.excludedDirectoryNames = const {
      'whatsapp animated gifs',
      'whatsapp voice notes',
      'voice notes',
      'notifications',
      'ringtones',
      '.trash',
      '.thumbnails',
      'cache',
      'android',
    },
    this.excludedAbsolutePaths = const {},
    this.maxRecursionDepth = 24,
    this.dbWriteBatchSize = 150,
  });

  ScanConfig copyWith({
    Set<String>? allowedExtensions,
    Duration? minTrackDuration,
    int? minFileSizeBytes,
    Set<String>? excludedDirectoryNames,
    Set<String>? excludedAbsolutePaths,
    int? maxRecursionDepth,
    int? dbWriteBatchSize,
  }) {
    return ScanConfig(
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
      minTrackDuration: minTrackDuration ?? this.minTrackDuration,
      minFileSizeBytes: minFileSizeBytes ?? this.minFileSizeBytes,
      excludedDirectoryNames:
          excludedDirectoryNames ?? this.excludedDirectoryNames,
      excludedAbsolutePaths:
          excludedAbsolutePaths ?? this.excludedAbsolutePaths,
      maxRecursionDepth: maxRecursionDepth ?? this.maxRecursionDepth,
      dbWriteBatchSize: dbWriteBatchSize ?? this.dbWriteBatchSize,
    );
  }

  bool isExtensionAllowed(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return false;
    return allowedExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  bool isDirectoryExcluded(String dirPath) {
    final segment =
        dirPath.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).lastOrNull;
    if (segment != null &&
        excludedDirectoryNames.contains(segment.toLowerCase())) {
      return true;
    }
    return excludedAbsolutePaths.contains(dirPath);
  }

  /// Serializes to a plain Map so a [ScanConfig] can be sent across the
  /// isolate boundary inside a [ScanRequest] (Isolate.spawn can only copy
  /// primitive/collection data, not arbitrary class instances with
  /// methods).
  Map<String, dynamic> toJson() => {
        'allowedExtensions': allowedExtensions.toList(),
        'minTrackDurationMs': minTrackDuration.inMilliseconds,
        'minFileSizeBytes': minFileSizeBytes,
        'excludedDirectoryNames': excludedDirectoryNames.toList(),
        'excludedAbsolutePaths': excludedAbsolutePaths.toList(),
        'maxRecursionDepth': maxRecursionDepth,
        'dbWriteBatchSize': dbWriteBatchSize,
      };

  factory ScanConfig.fromJson(Map<String, dynamic> json) => ScanConfig(
        allowedExtensions: Set<String>.from(json['allowedExtensions'] as List),
        minTrackDuration:
            Duration(milliseconds: json['minTrackDurationMs'] as int),
        minFileSizeBytes: json['minFileSizeBytes'] as int,
        excludedDirectoryNames:
            Set<String>.from(json['excludedDirectoryNames'] as List),
        excludedAbsolutePaths:
            Set<String>.from(json['excludedAbsolutePaths'] as List),
        maxRecursionDepth: json['maxRecursionDepth'] as int,
        dbWriteBatchSize: json['dbWriteBatchSize'] as int,
      );
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
