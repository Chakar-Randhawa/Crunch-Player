import 'package:isar/isar.dart';

part 'play_history.g.dart';

/// One row per completed (or substantially-played) listen. Track.playCount
/// is the fast denormalized counter for UI; this table is the source of
/// truth for time-windowed queries like "Most Played this month" and for
/// the heavy-rotation ranking algorithm, which weights recent plays higher
/// than old ones.
@collection
class PlayHistory {
  Id id = Isar.autoIncrement;

  @Index()
  late int trackId;

  @Index()
  late DateTime playedAt;

  /// Milliseconds of the track actually played before skip/stop. Used to
  /// distinguish a genuine listen from an accidental tap-and-skip — the
  /// scan/playback layer only writes a history row when this exceeds
  /// ScanConfig.minPlayDurationForHistoryMs.
  late int msPlayed;

  /// True if the track played to natural completion rather than being
  /// skipped or the app being backgrounded/killed mid-track.
  bool completed = false;
}
