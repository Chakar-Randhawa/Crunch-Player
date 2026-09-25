import 'package:isar/isar.dart';

part 'track.g.dart';

/// A single playable audio file indexed from local storage.
///
/// [filePath] is the unique on-disk identity used for de-duplication during
/// re-scans — a track is only ever inserted once per path, and subsequent
/// scans of the same path perform an update, not an insert.
@collection
class Track {
  Id id = Isar.autoIncrement;

  /// Absolute filesystem path. Unique index lets the scanner upsert in O(1)
  /// instead of scanning the whole table on every file it encounters.
  @Index(type: IndexType.hash, unique: true, replace: true)
  late String filePath;

  /// File name without extension, used as a fallback title and for search.
  @Index(type: IndexType.value, caseSensitive: false)
  late String fileName;

  @Index(type: IndexType.value, caseSensitive: false)
  String title = 'Unknown Title';

  @Index(type: IndexType.value, caseSensitive: false)
  String artistName = 'Unknown Artist';

  @Index(type: IndexType.value, caseSensitive: false)
  String albumName = 'Unknown Album';

  String genre = '';

  /// Track number within its album, 0 if absent from tags.
  int trackNumber = 0;

  /// Release year, 0 if absent from tags.
  int year = 0;

  /// Duration in milliseconds. 0 means "not yet resolved" — MP3/FLAC/WAV
  /// are resolved at scan time from format headers; formats the scanner
  /// can't cheaply parse (M4A/AAC/OGG container internals) are resolved
  /// lazily on first playback by the audio engine and written back here.
  int durationMs = 0;

  /// Bytes on disk, used by the size-based junk filter (see ScanConfig) and
  /// shown in track detail views.
  int fileSizeBytes = 0;

  /// File extension without the dot, lowercase — "mp3", "flac", etc.
  late String format;

  /// Bitrate in kbps if known from the format header, else 0.
  int bitrateKbps = 0;

  /// Foreign key to [Album.id]. -1 if the track has not been linked yet
  /// (linking happens in a second pass after all tracks in a batch are
  /// inserted, so album aggregation sees the full track set).
  int albumId = -1;

  /// Foreign key to [Artist.id]. -1 until the linking pass.
  int artistId = -1;

  /// Foreign key to [Folder.id]. -1 until the linking pass.
  int folderId = -1;

  @Index()
  bool isFavorite = false;

  /// Denormalized play counter, incremented directly on playback complete
  /// rather than derived from PlayHistory, so "Most Played" queries don't
  /// need an aggregation join on every render.
  @Index()
  int playCount = 0;

  DateTime? lastPlayedAt;

  /// When this row was first inserted — backs the "Recently Added" smart
  /// playlist.
  @Index()
  late DateTime dateAdded;

  /// Last-modified timestamp of the file itself, used to detect edits
  /// between scans without re-reading tags for every unchanged file.
  late DateTime fileModifiedAt;

  /// Time-synchronized lyrics as raw LRC text if embedded/sidecar lyrics
  /// were found; null if none. Parsed lazily by the lyrics view.
  String? syncedLyrics;

  /// Plain static lyrics if no time-synced source was available.
  String? staticLyrics;

  /// Combinatorial spectral-peak hashes from AudioFingerprinter, cached
  /// here so duplicate detection across the library only computes each
  /// track's fingerprint once. Empty until computed — see
  /// FingerprintService for the lazy-compute-on-demand flow.
  List<int> fingerprintHashes = [];

  Track();

  Track.placeholder({
    required this.filePath,
    required this.fileName,
    required this.format,
  }) {
    dateAdded = DateTime.now();
    fileModifiedAt = DateTime.now();
  }
}
