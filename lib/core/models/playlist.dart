import 'package:isar/isar.dart';

part 'playlist.g.dart';

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  /// Ordered Track.id list. Kept as a plain embedded list rather than a
  /// link — playlists need explicit user-controlled ordering (drag-and-
  /// drop reorder), which an Isar IsarLink's unordered set cannot express.
  List<int> trackIds = [];

  bool isSystemSmartPlaylist = false;

  /// Discriminator for built-in smart playlists (Favorites, Recently
  /// Added, Most Played). Null for user-created playlists.
  String? smartPlaylistType;

  late DateTime createdAt;

  DateTime? updatedAt;
}
