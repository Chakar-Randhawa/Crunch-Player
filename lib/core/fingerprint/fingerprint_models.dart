/// One entry in a track's fingerprint: a 32-bit combinatorial hash of two
/// spectral peaks plus the time delta between them (the same family of
/// technique Shazam's published algorithm uses), and the time offset (in
/// analysis frames) at which the anchor peak occurred.
class FingerprintHash {
  final int hash;
  final int anchorTimeFrame;
  const FingerprintHash(this.hash, this.anchorTimeFrame);

  /// Packs both fields into a single 64-bit int for storage in Isar's
  /// `List<int>` (Isar has no `List<Record>`/nested-object list support
  /// for a plain field like this) — anchorTimeFrame in the upper 32 bits,
  /// hash in the lower 32. A song would need to run for roughly 27 hours
  /// at this fingerprinter's ~46ms-per-frame hop size before
  /// anchorTimeFrame overflowed 32 bits, which is not a real constraint
  /// for a music track.
  int pack() => (anchorTimeFrame << 32) | (hash & 0xFFFFFFFF);

  static FingerprintHash unpack(int packed) {
    final anchorTimeFrame = packed >> 32;
    final hash = packed & 0xFFFFFFFF;
    return FingerprintHash(hash, anchorTimeFrame);
  }
}

class TrackFingerprint {
  final List<FingerprintHash> hashes;
  final Duration analysisDuration;
  const TrackFingerprint({required this.hashes, required this.analysisDuration});
}

class DuplicateMatch {
  final int candidateTrackId;
  final int matchingHashCount;
  final double confidence; // 0..1, matchingHashCount relative to the smaller track's total hash count
  const DuplicateMatch({
    required this.candidateTrackId,
    required this.matchingHashCount,
    required this.confidence,
  });
}
