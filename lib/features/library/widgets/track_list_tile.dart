import 'package:flutter/material.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';

class TrackListTile extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onMoreTap;

  const TrackListTile({
    super.key,
    required this.track,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onMoreTap,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ArtworkPlaceholder(isPlaying: isPlaying, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPlaying ? accent.primary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${track.artistName} • ${track.albumName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(track.durationMs),
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
            ),
            IconButton(
              splashRadius: 20,
              icon: Icon(
                track.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 19,
                color: track.isFavorite ? accent.primary : Colors.white.withOpacity(0.4),
              ),
              onPressed: onFavoriteToggle,
            ),
            IconButton(
              splashRadius: 20,
              icon: Icon(Icons.more_vert, size: 19, color: Colors.white.withOpacity(0.4)),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '--:--';
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Stand-in artwork tile until the embedded-cover-art extraction module is
/// wired in — a custom-painted waveform glyph rather than a placeholder
/// image asset, consistent with the no-raster-asset constraint elsewhere.
class _ArtworkPlaceholder extends StatelessWidget {
  final bool isPlaying;
  final AppAccent accent;
  const _ArtworkPlaceholder({required this.isPlaying, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        gradient: LinearGradient(
          colors: isPlaying
              ? [accent.primary, accent.secondary]
              : [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)],
        ),
      ),
      child: Icon(
        isPlaying ? Icons.graphic_eq : Icons.music_note,
        size: 20,
        color: isPlaying ? Colors.white : Colors.white.withOpacity(0.35),
      ),
    );
  }
}
