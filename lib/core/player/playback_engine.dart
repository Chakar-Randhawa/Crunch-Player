import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'queue_manager.dart';
import 'repeat_mode.dart';

/// Fired when a track finishes (or is skipped past) a threshold amount of
/// playback, so the caller (the audio_service handler) can commit a
/// PlayHistory row and bump Track.playCount. Kept as a simple record type
/// rather than a full event class since the handler only needs these
/// three values.
typedef PlaybackCommitCallback = void Function(Track track, int msPlayed, bool completedNaturally);

/// How much of a track must actually play before it counts as a genuine
/// listen for history/heavy-rotation purposes, rather than an
/// accidental tap-and-skip.
class PlaybackHistoryPolicy {
  const PlaybackHistoryPolicy._();

  static bool shouldRecord(int msPlayed, int durationMs) {
    if (durationMs <= 0) return msPlayed >= 20000; // unknown duration: fall back to an absolute floor
    final halfway = durationMs / 2;
    const absoluteFloor = 30000; // 30s
    return msPlayed >= absoluteFloor || msPlayed >= halfway;
  }
}

class PlaybackEngine {
  final QueueManager queueManager;
  final PlaybackCommitCallback onPlaybackCommit;

  Duration crossfadeDuration = Duration.zero;

  AudioPlayer _primary = AudioPlayer();
  AudioPlayer? _standby;
  bool _crossfadeInFlight = false;

  ConcatenatingAudioSource? _gaplessSource;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _gaplessIndexSub;

  Track? _lastCommittedTrack;
  int _lastKnownPositionMs = 0;
  bool _committedCurrentTrack = false;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _currentTrackController = StreamController<Track?>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _audioSessionIdController = StreamController<int>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;

  /// Emits the active AudioPlayer's native Android audio session id every
  /// time it changes — at first playback, and again on every crossfade
  /// swap, since a freshly-constructed AudioPlayer gets a brand new
  /// session id that any previously-attached AudioEffect (the equalizer)
  /// does not automatically follow. No-op stream on iOS/other platforms
  /// where androidAudioSessionId is always null.
  Stream<int> get audioSessionIdStream => _audioSessionIdController.stream;

  PlaybackEngine({required this.queueManager, required this.onPlaybackCommit}) {
    _bindPrimaryListeners();
  }

  bool get isGaplessMode => crossfadeDuration == Duration.zero;

  /// Switches transition mode. Rebuilds whatever source is currently
  /// loaded so the change takes effect on the very next track boundary
  /// rather than requiring a manual restart.
  Future<void> setCrossfadeDuration(Duration duration) async {
    crossfadeDuration = duration;
    final current = queueManager.currentTrack;
    if (current != null) {
      final position = _primary.position;
      await _loadQueueAtCurrentPosition(resumePosition: position, autoplay: _primary.playing);
    }
  }

  Future<void> loadAndPlayQueue(List<Track> tracks, int startIndex) async {
    queueManager.setQueue(tracks, startIndex: startIndex);
    _committedCurrentTrack = false;
    await _loadQueueAtCurrentPosition(autoplay: true);
  }

  Future<void> _loadQueueAtCurrentPosition({Duration? resumePosition, bool autoplay = false}) async {
    final current = queueManager.currentTrack;
    if (current == null) return;

    _currentTrackController.add(current);

    if (isGaplessMode) {
      await _loadGaplessFromCurrentPosition();
      if (resumePosition != null) await _primary.seek(resumePosition);
    } else {
      await _loadCrossfadeTrack(_primary, current);
      if (resumePosition != null) await _primary.seek(resumePosition);
    }

    if (autoplay) await play();
  }

  // -----------------------------------------------------------------
  // Gapless path: hand the whole play-order sequence to just_audio's
  // ConcatenatingAudioSource. This is what achieves a true 0ms boundary —
  // just_audio pre-buffers the next item internally, which a manual
  // "load next on completion" approach cannot match.
  // -----------------------------------------------------------------
  Future<void> _loadGaplessFromCurrentPosition() async {
    await _gaplessIndexSub?.cancel();

    final playOrderTracks = <Track>[];
    final startPos = queueManager.currentOriginalIndex;
    // Build the source starting at the current track so currentIndex in
    // just_audio's own player lines up with index 0, keeping the mapping
    // back to QueueManager simple.
    final all = queueManager.queueInOriginalOrder;
    if (startPos < 0 || all.isEmpty) return;

    playOrderTracks.addAll(all.sublist(startPos));
    playOrderTracks.addAll(all.sublist(0, startPos));

    _gaplessSource = ConcatenatingAudioSource(
      children: playOrderTracks.map((t) => AudioSource.uri(Uri.file(t.filePath))).toList(),
    );

    await _primary.setLoopMode(_mapRepeatToLoopMode(queueManager.repeatMode));
    await _primary.setAudioSource(_gaplessSource!, initialIndex: 0);

    _gaplessIndexSub = _primary.currentIndexStream.listen((index) {
      if (index == null) return;
      _commitIfDue(forceComplete: true);
      // just_audio's own index has advanced; keep QueueManager's notion of
      // "current" in lockstep so UI (now playing, up-next) stays correct.
      final targetOriginalIndex = playOrderTracks.isEmpty
          ? -1
          : all.indexOf(playOrderTracks[index % playOrderTracks.length]);
      if (targetOriginalIndex != -1 && targetOriginalIndex != queueManager.currentOriginalIndex) {
        while (queueManager.currentOriginalIndex != targetOriginalIndex && queueManager.advanceToNext()) {
          // drive QueueManager forward until it matches just_audio's
          // actual position; bounded by queue length so this can't loop
          // forever on a consistent state.
        }
        _committedCurrentTrack = false;
        _currentTrackController.add(queueManager.currentTrack);
      }
    });
  }

  LoopMode _mapRepeatToLoopMode(CraunchRepeatMode mode) {
    switch (mode) {
      case CraunchRepeatMode.off:
        return LoopMode.off;
      case CraunchRepeatMode.repeatOne:
        return LoopMode.one;
      case CraunchRepeatMode.repeatAll:
        return LoopMode.all;
    }
  }

  // -----------------------------------------------------------------
  // Crossfade path: two independent players. The standby player is
  // preloaded (but silent) once the active player enters the crossfade
  // window near the end of its track, then both volumes are ramped in
  // lockstep until the standby reaches full volume and becomes the new
  // active player.
  // -----------------------------------------------------------------
  void _bindPrimaryListeners() {
    _positionSub = _primary.positionStream.listen((position) {
      _lastKnownPositionMs = position.inMilliseconds;
      _positionController.add(position);

      if (!isGaplessMode) _maybeStartCrossfade(position);
    });

    _stateSub = _primary.playerStateStream.listen((state) {
      _playingController.add(state.playing);
      _bufferingController.add(state.processingState == ProcessingState.buffering);

      if (isGaplessMode && state.processingState == ProcessingState.completed) {
        _commitIfDue(forceComplete: true);
      }
    });

    _primary.durationStream.listen(_durationController.add);
    _emitAudioSessionId();
  }

  Future<void> _emitAudioSessionId() async {
    final sessionId = _primary.androidAudioSessionId;
    if (sessionId != null) _audioSessionIdController.add(sessionId);
  }

  Future<void> _loadCrossfadeTrack(AudioPlayer player, Track track) async {
    await player.setAudioSource(AudioSource.uri(Uri.file(track.filePath)));
    await player.setVolume(1.0);
  }

  Future<void> _maybeStartCrossfade(Duration position) async {
    if (_crossfadeInFlight) return;
    final duration = _primary.duration;
    if (duration == null || crossfadeDuration == Duration.zero) return;

    final remaining = duration - position;
    if (remaining > crossfadeDuration || remaining <= Duration.zero) return;

    final next = queueManager.peekNext();
    if (next == null || !File(next.filePath).existsSync()) return;

    _crossfadeInFlight = true;
    _commitIfDue(forceComplete: false);

    final standby = AudioPlayer();
    _standby = standby;
    await standby.setAudioSource(AudioSource.uri(Uri.file(next.filePath)));
    await standby.setVolume(0.0);
    await standby.play();

    final steps = 20;
    final stepDuration = Duration(milliseconds: crossfadeDuration.inMilliseconds ~/ steps);
    for (int i = 1; i <= steps; i++) {
      if (_standby != standby) return; // superseded by a manual skip mid-fade
      final t = i / steps;
      await Future.wait([
        _primary.setVolume((1.0 - t).clamp(0.0, 1.0)),
        standby.setVolume(t.clamp(0.0, 1.0)),
      ]);
      await Future.delayed(stepDuration);
    }

    // Swap roles: the old primary is torn down, standby becomes primary,
    // and every listener is rebound so the public streams keep emitting
    // from whichever AudioPlayer is now authoritative.
    final old = _primary;
    _primary = standby;
    _standby = null;
    _crossfadeInFlight = false;

    await _positionSub?.cancel();
    await _stateSub?.cancel();
    _bindPrimaryListeners();

    queueManager.advanceToNext();
    _committedCurrentTrack = false;
    _currentTrackController.add(queueManager.currentTrack);

    await old.stop();
    await old.dispose();
  }

  // -----------------------------------------------------------------
  // Transport controls
  // -----------------------------------------------------------------
  Future<void> play() => _primary.play();
  Future<void> pause() => _primary.pause();
  Future<void> seek(Duration position) => _primary.seek(position);

  /// Ramps volume to zero over [duration] then pauses — used by the
  /// movement-based and fixed-duration sleep timers so playback winds
  /// down gently rather than cutting off mid-note. Volume is restored to
  /// full before the next explicit `play()` call, so a subsequent manual
  /// resume doesn't start silent.
  Future<void> fadeOutAndPause(Duration duration) async {
    const steps = 30;
    final stepDuration = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    for (int i = 1; i <= steps; i++) {
      final volume = (1.0 - i / steps).clamp(0.0, 1.0);
      await _primary.setVolume(volume);
      await Future.delayed(stepDuration);
    }
    await _primary.pause();
    await _primary.setVolume(1.0);
  }

  Future<void> skipToNext() async {
    _commitIfDue(forceComplete: false);
    if (isGaplessMode) {
      if (_gaplessSource != null && _primary.hasNext) {
        await _primary.seekToNext();
      }
    } else {
      if (!queueManager.advanceToNext()) return;
      _committedCurrentTrack = false;
      final track = queueManager.currentTrack;
      if (track != null) {
        _currentTrackController.add(track);
        await _loadCrossfadeTrack(_primary, track);
        await play();
      }
    }
  }

  Future<void> skipToPrevious() async {
    _commitIfDue(forceComplete: false);
    if (isGaplessMode) {
      if (_gaplessSource != null && _primary.hasPrevious) {
        await _primary.seekToPrevious();
      }
    } else {
      if (!queueManager.retreatToPrevious()) return;
      _committedCurrentTrack = false;
      final track = queueManager.currentTrack;
      if (track != null) {
        _currentTrackController.add(track);
        await _loadCrossfadeTrack(_primary, track);
        await play();
      }
    }
  }

  Future<void> setShuffle(bool enabled) async {
    queueManager.setShuffle(enabled);
    if (isGaplessMode) await _loadGaplessFromCurrentPosition();
  }

  Future<void> setRepeatMode(CraunchRepeatMode mode) async {
    queueManager.setRepeatMode(mode);
    if (isGaplessMode) await _primary.setLoopMode(_mapRepeatToLoopMode(mode));
  }

  void _commitIfDue({required bool forceComplete}) {
    final track = queueManager.currentTrack;
    if (track == null || _committedCurrentTrack) return;
    if (track == _lastCommittedTrack && _committedCurrentTrack) return;

    final shouldRecord = forceComplete ||
        PlaybackHistoryPolicy.shouldRecord(_lastKnownPositionMs, track.durationMs);
    if (shouldRecord) {
      onPlaybackCommit(track, _lastKnownPositionMs, forceComplete);
      _committedCurrentTrack = true;
      _lastCommittedTrack = track;
    }
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _gaplessIndexSub?.cancel();
    await _primary.dispose();
    await _standby?.dispose();
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _currentTrackController.close();
    await _bufferingController.close();
    await _audioSessionIdController.close();
  }
}
