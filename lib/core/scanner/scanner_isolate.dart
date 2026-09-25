import 'dart:io';
import 'dart:isolate';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../database/isar_service.dart';
import '../models/track.dart';
import 'audio_tag_reader.dart';
import 'library_linker.dart';
import 'scan_config.dart';
import 'scan_progress.dart';

/// Top-level (not a class method) so it's a valid [Isolate.spawn] entry
/// point — spawn requires a static or top-level function reference.
void scannerIsolateEntryPoint(ScanRequest request) {
  _runScan(request);
}

Future<void> _runScan(ScanRequest request) async {
  final sendPort = request.replyPort;
  final config = ScanConfig.fromJson(request.scanConfigJson);
  const tagReader = AudioTagReader();
  const linker = LibraryLinker();

  var progress = const ScanProgress(phase: ScanPhase.walkingDirectories);
  sendPort.send(progress);

  try {
    // Isar supports the same named instance being opened from multiple
    // isolates concurrently, so the scanner writes straight to the DB
    // instead of shuttling every parsed Track back through a port.
    final isar = await Isar.open(
      [TrackSchema],
      directory: request.isarDirectoryPath,
      name: 'craunch_player_db',
      inspector: false,
    );

    // --- Phase 1: walk directories and collect candidate file paths -----
    final candidatePaths = <String>[];
    for (final root in request.rootPaths) {
      await _walk(
        Directory(root),
        config,
        depth: 0,
        onFile: (path) => candidatePaths.add(path),
        onDirectoryVisited: (path) {
          progress = progress.copyWith(currentPath: path);
          sendPort.send(progress);
        },
      );
    }

    progress = progress.copyWith(
      phase: ScanPhase.readingTags,
      filesFound: candidatePaths.length,
    );
    sendPort.send(progress);

    // --- Phase 2: read tags, filter junk, batch-write --------------------
    var buffer = <Track>[];
    var processed = 0;
    var inserted = 0;
    var skipped = 0;

    for (final path in candidatePaths) {
      processed++;
      final file = File(path);

      late final FileStat stat;
      try {
        stat = await file.stat();
      } catch (_) {
        skipped++;
        continue;
      }

      if (stat.size < config.minFileSizeBytes) {
        skipped++;
        continue;
      }

      final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
      AudioTagResult tags;
      try {
        tags = await tagReader.read(file, extension);
      } catch (_) {
        tags = AudioTagResult();
      }

      // The core junk filter: WhatsApp/Telegram voice notes match an
      // allowed extension but are almost always well under the configured
      // minimum. A file whose duration couldn't be determined (some AAC/
      // OGG edge cases) is kept rather than dropped, since size already
      // passed the floor check above.
      if (tags.durationMs != null && tags.durationMs! < config.minTrackDuration.inMilliseconds) {
        skipped++;
        continue;
      }

      final fileNameNoExt = p.basenameWithoutExtension(path);

      final track = Track.placeholder(
        filePath: path,
        fileName: fileNameNoExt,
        format: extension,
      )
        ..title = _cleanOrFallback(tags.title, fileNameNoExt)
        ..artistName = _cleanOrFallback(tags.artist, 'Unknown Artist')
        ..albumName = _cleanOrFallback(tags.album, 'Unknown Album')
        ..genre = tags.genre?.trim() ?? ''
        ..trackNumber = tags.trackNumber ?? 0
        ..year = tags.year ?? 0
        ..durationMs = tags.durationMs ?? 0
        ..fileSizeBytes = stat.size
        ..bitrateKbps = tags.bitrateKbps ?? 0
        ..fileModifiedAt = stat.modified;

      buffer.add(track);
      inserted++;

      if (buffer.length >= config.dbWriteBatchSize) {
        await _flushBatch(isar, buffer);
        buffer = [];
      }

      if (processed % 25 == 0 || processed == candidatePaths.length) {
        progress = progress.copyWith(
          filesProcessed: processed,
          tracksInserted: inserted,
          tracksSkipped: skipped,
          currentPath: path,
        );
        sendPort.send(progress);
      }
    }

    if (buffer.isNotEmpty) {
      await _flushBatch(isar, buffer);
    }

    // --- Phase 3: link tracks into Album/Artist/Folder aggregates -------
    progress = progress.copyWith(phase: ScanPhase.linkingLibrary);
    sendPort.send(progress);

    await linker.relinkAll(isar);

    progress = progress.copyWith(phase: ScanPhase.complete);
    sendPort.send(progress);
  } catch (e) {
    sendPort.send(progress.copyWith(phase: ScanPhase.error, errorMessage: e.toString()));
  }
}

Future<void> _flushBatch(Isar isar, List<Track> batch) async {
  await isar.writeTxn(() async {
    await isar.tracks.putAll(batch);
  });
}

String _cleanOrFallback(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

/// Recursively walks [dir], invoking [onFile] for every path that passes
/// the extension/exclusion filters and [onDirectoryVisited] for progress
/// reporting. Recursion depth is capped by [ScanConfig.maxRecursionDepth]
/// as a guard against symlink cycles.
Future<void> _walk(
  Directory dir,
  ScanConfig config, {
  required int depth,
  required void Function(String path) onFile,
  required void Function(String path) onDirectoryVisited,
}) async {
  if (depth > config.maxRecursionDepth) return;
  if (config.isDirectoryExcluded(dir.path)) return;

  onDirectoryVisited(dir.path);

  List<FileSystemEntity> entries;
  try {
    entries = await dir.list(followLinks: false).toList();
  } catch (_) {
    // Permission-denied or transiently-unavailable directories (e.g. an
    // SD card unmounted mid-scan) are skipped rather than aborting the
    // whole scan.
    return;
  }

  for (final entity in entries) {
    if (entity is Directory) {
      await _walk(
        entity,
        config,
        depth: depth + 1,
        onFile: onFile,
        onDirectoryVisited: onDirectoryVisited,
      );
    } else if (entity is File) {
      if (config.isExtensionAllowed(entity.path)) {
        onFile(entity.path);
      }
    }
  }
}
