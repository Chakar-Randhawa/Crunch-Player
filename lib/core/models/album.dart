import 'package:isar/isar.dart';

part 'album.g.dart';

@collection
class Album {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.hash, unique: true, replace: true)
  late String albumKey; // "${albumName}::${artistName}", lowercased — de-dup key

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  late String primaryArtistName;

  int year = 0;

  int trackCount = 0;

  int totalDurationMs = 0;

  /// Path to the first track's file, used to derive embedded cover art
  /// on demand rather than duplicating image bytes per album row.
  String? artworkSourceTrackPath;

  /// Dominant colors extracted from cover art by palette_generator, cached
  /// so the dynamic-theme feature doesn't recompute on every open.
  int? paletteColorPrimary;
  int? paletteColorSecondary;
}
