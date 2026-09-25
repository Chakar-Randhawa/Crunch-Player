import '../database/isar_service.dart';
import '../models/track.dart';
import 'audio_fingerprinter.dart';
import 'fingerprint_index.dart';
import 'fingerprint_models.dart';

class FingerprintService {
  final AudioFingerprinter _fingerprinter;
  final FingerprintIndex _index = FingerprintIndex();
  bool _indexBuiltFromCache = false;

  FingerprintService({AudioFingerprinter? fingerprinter})
      : _fingerprinter = fingerprinter ?? AudioFingerprinter();

  /// Computes (or reads the cached) fingerprint for [track], writing it
  /// back to Isar the first time so a re-scan or app restart doesn't
  /// re-run the FFT/hashing pass over audio that's already been analyzed.
  Future<TrackFingerprint> ensureFingerprint(Track track) async {
    if (track.fingerprintHashes.isNotEmpty) {
      return _fromPacked(track.fingerprintHashes);
    }

    final fingerprint = await _fingerprinter.generate(track.filePath);

    final isar = await IsarService.instance.open();
    await isar.writeTxn(() async {
      final fresh = await isar.tracks.get(track.id);
      if (fresh != null) {
        fresh.fingerprintHashes =
            fingerprint.hashes.map((h) => h.pack()).toList();
        await isar.tracks.put(fresh);
      }
    });

    _index.addTrack(track.id, fingerprint);
    return fingerprint;
  }

  /// Loads every track's cached fingerprint (skipping ones not yet
  /// computed — this does not trigger computation for the whole library
  /// at once, since that's a genuinely heavy batch operation the caller
  /// should drive explicitly, e.g. from a "Find duplicates" settings
  /// action with its own progress UI) into the in-memory index once per
  /// app session.
  Future<void> loadCachedFingerprintsIntoIndex() async {
    if (_indexBuiltFromCache) return;
    _indexBuiltFromCache = true;

    final isar = await IsarService.instance.open();
    final tracksWithFingerprints =
        await isar.tracks.filter().fingerprintHashesIsNotEmpty().findAll();

    for (final track in tracksWithFingerprints) {
      _index.addTrack(track.id, _fromPacked(track.fingerprintHashes));
    }
  }

  Future<List<DuplicateMatch>> findDuplicatesFor(Track track) async {
    await loadCachedFingerprintsIntoIndex();
    final fingerprint = await ensureFingerprint(track);
    return _index.findDuplicates(fingerprint, excludeTrackId: track.id);
  }

  TrackFingerprint _fromPacked(List<int> packed) {
    return TrackFingerprint(
      hashes: packed.map(FingerprintHash.unpack).toList(),
      analysisDuration: Duration
          .zero, // not needed for matching; only used at generation time
    );
  }
}
