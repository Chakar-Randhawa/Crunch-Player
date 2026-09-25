import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../models/track.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/folder.dart';

/// Runs after all files in a scan batch have been written as [Track] rows.
/// Aggregation happens as a distinct pass — rather than upserting
/// Album/Artist/Folder rows per-file during the walk — so that counts like
/// [Album.trackCount] reflect the complete, final set of tracks in one
/// consistent pass instead of being incrementally (and error-pronely)
/// patched file-by-file.
class LibraryLinker {
  const LibraryLinker();

  Future<void> relinkAll(Isar isar) async {
    final tracks = await isar.tracks.where().findAll();
    if (tracks.isEmpty) return;

    final albumBuckets = <String, List<Track>>{};
    final artistBuckets = <String, List<Track>>{};
    final folderBuckets = <String, List<Track>>{};

    for (final track in tracks) {
      final albumKey = _albumKey(track.albumName, track.artistName);
      final artistKey = track.artistName.trim().toLowerCase();
      final folderPath = p.dirname(track.filePath);

      albumBuckets.putIfAbsent(albumKey, () => []).add(track);
      artistBuckets.putIfAbsent(artistKey, () => []).add(track);
      folderBuckets.putIfAbsent(folderPath, () => []).add(track);
    }

    final albumIdByKey = <String, int>{};
    final artistIdByKey = <String, int>{};
    final folderIdByPath = <String, int>{};

    await isar.writeTxn(() async {
      for (final entry in albumBuckets.entries) {
        final sample = entry.value.first;
        final album = Album()
          ..albumKey = entry.key
          ..name = sample.albumName
          ..primaryArtistName = _mostCommonArtist(entry.value)
          ..year = _mostCommonYear(entry.value)
          ..trackCount = entry.value.length
          ..totalDurationMs = entry.value.fold(0, (sum, t) => sum + t.durationMs)
          ..artworkSourceTrackPath = sample.filePath;
        final id = await isar.albums.put(album);
        albumIdByKey[entry.key] = id;
      }

      for (final entry in artistBuckets.entries) {
        final albumKeysForArtist = entry.value.map((t) => _albumKey(t.albumName, t.artistName)).toSet();
        final artist = Artist()
          ..nameKey = entry.key
          ..name = entry.value.first.artistName
          ..trackCount = entry.value.length
          ..albumCount = albumKeysForArtist.length;
        final id = await isar.artists.put(artist);
        artistIdByKey[entry.key] = id;
      }

      for (final entry in folderBuckets.entries) {
        final folder = Folder()
          ..path = entry.key
          ..displayName = p.basename(entry.key)
          ..parentFolderId = -1
          ..trackCount = entry.value.length;
        final id = await isar.folders.put(folder);
        folderIdByPath[entry.key] = id;
      }

      // Second sub-pass: now that every Folder row exists, resolve each
      // folder's parentFolderId so the folder-browser can render a tree
      // instead of a flat list.
      for (final entry in folderIdByPath.entries) {
        final parentPath = p.dirname(entry.key);
        final parentId = folderIdByPath[parentPath];
        if (parentId != null && parentId != entry.value) {
          final folder = await isar.folders.get(entry.value);
          if (folder != null) {
            folder.parentFolderId = parentId;
            await isar.folders.put(folder);
          }
        }
      }

      for (final track in tracks) {
        track.albumId = albumIdByKey[_albumKey(track.albumName, track.artistName)] ?? -1;
        track.artistId = artistIdByKey[track.artistName.trim().toLowerCase()] ?? -1;
        track.folderId = folderIdByPath[p.dirname(track.filePath)] ?? -1;
      }
      await isar.tracks.putAll(tracks);
    });
  }

  String _albumKey(String albumName, String artistName) =>
      '${albumName.trim().toLowerCase()}::${artistName.trim().toLowerCase()}';

  String _mostCommonArtist(List<Track> tracks) {
    final counts = <String, int>{};
    for (final t in tracks) {
      counts[t.artistName] = (counts[t.artistName] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int _mostCommonYear(List<Track> tracks) {
    final counts = <int, int>{};
    for (final t in tracks) {
      if (t.year == 0) continue;
      counts[t.year] = (counts[t.year] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
