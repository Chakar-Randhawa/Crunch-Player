import 'dart:math';

import '../models/track.dart';
import 'repeat_mode.dart';

/// Owns the ordered list of tracks currently queued for playback, plus the
/// shuffle permutation and repeat mode. This class contains no audio
/// engine logic at all — it only answers "what track is current" and
/// "what track comes next", so it's trivially unit-testable without a
/// real audio backend.
class QueueManager {
  List<Track> _originalOrder = [];
  List<int> _playOrder = []; // indices into _originalOrder
  int _positionInPlayOrder = -1;

  bool _shuffleEnabled = false;
  CraunchRepeatMode _repeatMode = CraunchRepeatMode.off;

  final Random _random;

  QueueManager({Random? random}) : _random = random ?? Random();

  List<Track> get queueInOriginalOrder => List.unmodifiable(_originalOrder);

  /// The queue as the user should actually see and reorder it — in play
  /// order, which differs from original order whenever shuffle is on.
  /// Drag-and-drop reordering operates on *this* list's indices via
  /// [reorderInPlayOrder], not the original order's.
  List<Track> get queueInPlayOrder =>
      List.unmodifiable(_playOrder.map((i) => _originalOrder[i]));

  int get currentPlayOrderPosition => _positionInPlayOrder;

  bool get shuffleEnabled => _shuffleEnabled;
  CraunchRepeatMode get repeatMode => _repeatMode;

  Track? get currentTrack {
    if (_positionInPlayOrder < 0 || _positionInPlayOrder >= _playOrder.length)
      return null;
    return _originalOrder[_playOrder[_positionInPlayOrder]];
  }

  int get currentOriginalIndex =>
      _positionInPlayOrder >= 0 && _positionInPlayOrder < _playOrder.length
          ? _playOrder[_positionInPlayOrder]
          : -1;

  bool get hasNext {
    if (_repeatMode == CraunchRepeatMode.repeatAll ||
        _repeatMode == CraunchRepeatMode.repeatOne) {
      return _playOrder.isNotEmpty;
    }
    return _positionInPlayOrder + 1 < _playOrder.length;
  }

  bool get hasPrevious =>
      _positionInPlayOrder > 0 || _repeatMode == CraunchRepeatMode.repeatAll;

  /// Replaces the queue entirely and starts playback intent at
  /// [startIndex] within [tracks] (index into the list as given, before
  /// any shuffle permutation is applied).
  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    _originalOrder = List.of(tracks);
    _playOrder = List.generate(_originalOrder.length, (i) => i);
    if (_shuffleEnabled) _shufflePlayOrderKeepingCurrentFirst(startIndex);
    _positionInPlayOrder = _shuffleEnabled
        ? 0
        : startIndex.clamp(0, max(_playOrder.length - 1, 0));
  }

  void appendToQueue(Track track) {
    _originalOrder.add(track);
    _playOrder.add(_originalOrder.length - 1);
  }

  /// Removes the track at [originalIndex] from both the original order and
  /// wherever it currently sits in the shuffled play order, adjusting the
  /// current position so playback doesn't jump unexpectedly.
  void removeAt(int originalIndex) {
    if (originalIndex < 0 || originalIndex >= _originalOrder.length) return;

    final removedWasCurrent = originalIndex == currentOriginalIndex;
    _originalOrder.removeAt(originalIndex);

    _playOrder.remove(originalIndex);
    _playOrder = _playOrder.map((i) => i > originalIndex ? i - 1 : i).toList();

    if (removedWasCurrent) {
      _positionInPlayOrder =
          _positionInPlayOrder.clamp(0, max(_playOrder.length - 1, 0));
    } else {
      _positionInPlayOrder = _playOrder.indexOf(currentOriginalIndex);
    }
  }

  /// Same removal as [removeAt], but addressed by position in the
  /// *visible* play order (what the queue screen actually shows and lets
  /// the user swipe-to-remove) rather than the original insertion order —
  /// the two only coincide when shuffle is off.
  void removeAtVisualIndex(int visualIndex) {
    if (visualIndex < 0 || visualIndex >= _playOrder.length) return;
    removeAt(_playOrder[visualIndex]);
  }

  /// Drag-and-drop reorder within the *play order* (i.e. what the queue
  /// screen visually shows right now, shuffle or not).
  void reorderInPlayOrder(int fromVisualIndex, int toVisualIndex) {
    if (fromVisualIndex < 0 || fromVisualIndex >= _playOrder.length) return;
    final movingCurrent = fromVisualIndex == _positionInPlayOrder;

    final item = _playOrder.removeAt(fromVisualIndex);
    final insertAt =
        toVisualIndex > fromVisualIndex ? toVisualIndex - 1 : toVisualIndex;
    _playOrder.insert(insertAt.clamp(0, _playOrder.length), item);

    if (movingCurrent) {
      _positionInPlayOrder = insertAt.clamp(0, _playOrder.length - 1);
    } else {
      _positionInPlayOrder = _playOrder.indexOf(currentOriginalIndex);
    }
  }

  void setShuffle(bool enabled) {
    if (enabled == _shuffleEnabled) return;
    _shuffleEnabled = enabled;
    final currentOriginal = currentOriginalIndex;
    if (enabled) {
      _shufflePlayOrderKeepingCurrentFirst(currentOriginal);
      _positionInPlayOrder = 0;
    } else {
      _playOrder = List.generate(_originalOrder.length, (i) => i);
      _positionInPlayOrder = currentOriginal >= 0 ? currentOriginal : 0;
    }
  }

  void setRepeatMode(CraunchRepeatMode mode) => _repeatMode = mode;

  /// Advances to the next track per current shuffle/repeat rules. Returns
  /// false if there is nowhere to advance to (end of queue, no repeat).
  bool advanceToNext() {
    if (_playOrder.isEmpty) return false;

    if (_repeatMode == CraunchRepeatMode.repeatOne) {
      return true; // caller re-seeks the same track to position 0
    }

    if (_positionInPlayOrder + 1 < _playOrder.length) {
      _positionInPlayOrder++;
      return true;
    }

    if (_repeatMode == CraunchRepeatMode.repeatAll) {
      if (_shuffleEnabled) _reshuffleFully();
      _positionInPlayOrder = 0;
      return true;
    }

    return false;
  }

  bool retreatToPrevious() {
    if (_positionInPlayOrder <= 0) {
      if (_repeatMode == CraunchRepeatMode.repeatAll && _playOrder.isNotEmpty) {
        _positionInPlayOrder = _playOrder.length - 1;
        return true;
      }
      return false;
    }
    _positionInPlayOrder--;
    return true;
  }

  /// Peeks the track that would play after the current one, without
  /// mutating position — used by the crossfade engine to pre-load the
  /// next source ahead of the current track ending.
  Track? peekNext() {
    if (_repeatMode == CraunchRepeatMode.repeatOne) return currentTrack;
    if (_positionInPlayOrder + 1 < _playOrder.length) {
      return _originalOrder[_playOrder[_positionInPlayOrder + 1]];
    }
    if (_repeatMode == CraunchRepeatMode.repeatAll && _playOrder.isNotEmpty) {
      return _originalOrder[_playOrder[0]];
    }
    return null;
  }

  void _shufflePlayOrderKeepingCurrentFirst(int keepOriginalIndex) {
    final indices = List.generate(_originalOrder.length, (i) => i);
    indices.shuffle(_random);
    if (keepOriginalIndex >= 0) {
      indices.remove(keepOriginalIndex);
      indices.insert(0, keepOriginalIndex);
    }
    _playOrder = indices;
  }

  void _reshuffleFully() {
    _playOrder.shuffle(_random);
  }
}
