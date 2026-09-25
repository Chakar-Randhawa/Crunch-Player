import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/folder.dart';
import '../models/playlist.dart';
import '../models/play_history.dart';

/// Opens and holds the single Isar instance used across the app. Isar
/// supports multiple isolates attaching to the same named instance
/// concurrently, which is what lets the scanner isolate write directly to
/// the database instead of marshalling every track back through the main
/// isolate via a port.
class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  static const String _instanceName = 'craunch_player_db';

  Isar? _isar;

  /// Returns the already-open instance if this isolate has one, otherwise
  /// opens it. Safe to call from both the UI isolate and the scanner
  /// isolate — [Isar.getInstance] checks for an existing named instance
  /// before [Isar.open] creates a new on-disk connection.
  Future<Isar> open() async {
    final existing = Isar.getInstance(_instanceName);
    if (existing != null) {
      _isar = existing;
      return existing;
    }

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        TrackSchema,
        AlbumSchema,
        ArtistSchema,
        FolderSchema,
        PlaylistSchema,
        PlayHistorySchema,
      ],
      directory: dir.path,
      name: _instanceName,
      inspector: false,
    );
    _isar = isar;
    return isar;
  }

  Isar get requireOpen {
    final isar = _isar;
    if (isar == null) {
      throw StateError('IsarService.open() must be awaited before use.');
    }
    return isar;
  }
}
