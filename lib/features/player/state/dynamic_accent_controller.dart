import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/artwork/embedded_artwork_extractor.dart';
import '../../../core/database/isar_service.dart';
import '../../../core/models/album.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';

/// Listens for the currently playing track, extracts its embedded artwork
/// (once per album — cached on the Album row so replaying a song doesn't
/// re-decode the same image), computes a dominant/vibrant color pair via
/// palette_generator, and exposes it as a [ValueNotifier<AppAccent>] that
/// the app root feeds into [AccentScope]. This is what makes the edge
/// glow and themed gradients react to the track that's actually playing.
class DynamicAccentController extends ValueNotifier<AppAccent> {
  final EmbeddedArtworkExtractor _artworkExtractor;
  int? _lastProcessedAlbumId;

  DynamicAccentController({EmbeddedArtworkExtractor? artworkExtractor})
      : _artworkExtractor =
            artworkExtractor ?? const EmbeddedArtworkExtractor(),
        super(AppAccent.fallback);

  Future<void> onTrackChanged(Track? track) async {
    if (track == null) {
      value = AppAccent.fallback;
      _lastProcessedAlbumId = null;
      return;
    }

    if (track.albumId == _lastProcessedAlbumId && track.albumId != -1) {
      return; // same album as last time — whatever accent is live already matches
    }

    final isar = await IsarService.instance.open();
    final cachedAlbum =
        track.albumId != -1 ? await isar.albums.get(track.albumId) : null;

    if (cachedAlbum != null &&
        cachedAlbum.paletteColorPrimary != null &&
        cachedAlbum.paletteColorSecondary != null) {
      _lastProcessedAlbumId = track.albumId;
      value = AppAccent(
        primary: Color(cachedAlbum.paletteColorPrimary!),
        secondary: Color(cachedAlbum.paletteColorSecondary!),
      );
      return;
    }

    final accent = await _extractAndCompute(track);
    _lastProcessedAlbumId = track.albumId;
    value = accent;

    if (cachedAlbum != null) {
      await isar.writeTxn(() async {
        cachedAlbum.paletteColorPrimary = accent.primary.value;
        cachedAlbum.paletteColorSecondary = accent.secondary.value;
        await isar.albums.put(cachedAlbum);
      });
    }
  }

  Future<AppAccent> _extractAndCompute(Track track) async {
    try {
      final file = File(track.filePath);
      if (!await file.exists()) return AppAccent.fallback;

      final artwork = await _artworkExtractor.extract(file, track.format);
      if (!artwork.hasArtwork) return AppAccent.fallback;

      final image = await _decodeImage(artwork.bytes!);
      if (image == null) return AppAccent.fallback;

      final palette = await PaletteGenerator.fromImage(
        image,
        maximumColorCount: 24,
      );

      final vibrant =
          palette.vibrantColor?.color ?? palette.dominantColor?.color;
      final muted = palette.mutedColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.lightVibrantColor?.color;

      if (vibrant == null) return AppAccent.fallback;

      return AppAccent(
        primary: vibrant,
        secondary: muted ?? _shiftHue(vibrant, 40),
      );
    } catch (_) {
      // A corrupt embedded image or an unsupported codec falls back to the
      // default accent rather than crashing the now-playing screen.
      return AppAccent.fallback;
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Color _shiftHue(Color base, double degrees) {
    final hsl = HSLColor.fromColor(base);
    final shifted = hsl.withHue((hsl.hue + degrees) % 360);
    return shifted.toColor();
  }
}
