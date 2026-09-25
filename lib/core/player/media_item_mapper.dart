import 'package:audio_service/audio_service.dart';

import '../models/track.dart';

class MediaItemMapper {
  const MediaItemMapper._();

  static MediaItem fromTrack(Track track) {
    return MediaItem(
      id: track.filePath,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      genre: track.genre.isEmpty ? null : track.genre,
      duration: track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null,
      extras: {'trackDbId': track.id},
    );
  }
}
