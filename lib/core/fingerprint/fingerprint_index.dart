import 'fingerprint_models.dart';

/// Maintains an inverted index (hash → list of (trackId, anchorTime)
/// entries) across the whole library, so checking a new/changed track
/// for duplicates is proportional to that track's own hash count, not to
/// the size of the library — the naive alternative (comparing every
/// track's fingerprint against every other track's) would be O(n²) and
/// become impractical past a few thousand songs.
class FingerprintIndex {
  final Map<int, List<_IndexEntry>> _hashToEntries = {};
  final Map<int, int> _trackHashCounts = {};

  void addTrack(int trackId, TrackFingerprint fingerprint) {
    removeTrack(trackId); // idempotent — re-indexing a re-scanned track replaces its old entries
    _trackHashCounts[trackId] = fingerprint.hashes.length;

    for (final h in fingerprint.hashes) {
      _hashToEntries.putIfAbsent(h.hash, () => []).add(_IndexEntry(trackId, h.anchorTimeFrame));
    }
  }

  void removeTrack(int trackId) {
    if (!_trackHashCounts.containsKey(trackId)) return;
    _trackHashCounts.remove(trackId);
    for (final entries in _hashToEntries.values) {
      entries.removeWhere((e) => e.trackId == trackId);
    }
  }

  /// Finds tracks whose fingerprint substantially overlaps [fingerprint],
  /// excluding [excludeTrackId] (the track being checked, if it's already
  /// indexed). Matching uses time-offset histogram voting — the standard
  /// technique for this hash family: a true match has many hash
  /// collisions that all agree on roughly the same time offset between
  /// the two tracks' anchor frames, whereas coincidental single-hash
  /// collisions (which do happen — the hash space isn't collision-free)
  /// scatter across many different offsets and don't accumulate votes.
  List<DuplicateMatch> findDuplicates(
    TrackFingerprint fingerprint, {
    int? excludeTrackId,
    int minMatchingHashes = 40,
    double minConfidence = 0.15,
  }) {
    // trackId -> (timeOffset -> voteCount)
    final votesByTrack = <int, Map<int, int>>{};

    for (final h in fingerprint.hashes) {
      final candidates = _hashToEntries[h.hash];
      if (candidates == null) continue;

      for (final candidate in candidates) {
        if (candidate.trackId == excludeTrackId) continue;
        final offset = candidate.anchorTimeFrame - h.anchorTimeFrame;
        final votes = votesByTrack.putIfAbsent(candidate.trackId, () => {});
        votes[offset] = (votes[offset] ?? 0) + 1;
      }
    }

    final results = <DuplicateMatch>[];
    for (final entry in votesByTrack.entries) {
      var bestOffsetVotes = 0;
      for (final v in entry.value.values) {
        if (v > bestOffsetVotes) bestOffsetVotes = v;
      }
      if (bestOffsetVotes < minMatchingHashes) continue;

      final candidateHashCount = _trackHashCounts[entry.key] ?? 1;
      final smallerCount = fingerprint.hashes.length < candidateHashCount
          ? fingerprint.hashes.length
          : candidateHashCount;
      final confidence = smallerCount == 0 ? 0.0 : bestOffsetVotes / smallerCount;

      if (confidence >= minConfidence) {
        results.add(DuplicateMatch(
          candidateTrackId: entry.key,
          matchingHashCount: bestOffsetVotes,
          confidence: confidence.clamp(0.0, 1.0),
        ));
      }
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  void clear() {
    _hashToEntries.clear();
    _trackHashCounts.clear();
  }
}

class _IndexEntry {
  final int trackId;
  final int anchorTimeFrame;
  const _IndexEntry(this.trackId, this.anchorTimeFrame);
}
