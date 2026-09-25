import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:isar/isar.dart';

import '../database/isar_service.dart';
import '../equalizer/equalizer_controller.dart';
import '../models/play_history.dart';
import '../models/track.dart';
import '../sleep_timer/movement_sleep_timer.dart';
import 'media_item_mapper.dart';
import 'playback_engine.dart';
import 'queue_manager.dart';
import 'repeat_mode.dart';

/// The single AudioHandler instance registered with audio_service at app
/// start. This is the only class that knows about audio_service's
/// MediaItem/PlaybackState types — PlaybackEngine and QueueManager stay
/// framework-agnostic so they can be unit tested without a platform
/// channel.
class CraunchAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  late final PlaybackEngine _engine;
  final QueueManager _queueManager = QueueManager();
  final EqualizerController equalizer = EqualizerController();
  late final MovementSleepTimer sleepTimer;

  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _trackSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _sessionIdSub;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _buffering = false;

  /// Exposes the engine's current-track stream publicly so UI-layer
  /// listeners (the dynamic album-color-sync controller, the edge glow
  /// overlay) can react to track changes without reaching into the
  /// private PlaybackEngine instance.
  Stream<Track?> get currentTrackStream => _engine.currentTrackStream;

  CraunchAudioHandler() {
    _engine = PlaybackEngine(
      queueManager: _queueManager,
      onPlaybackCommit: _commitPlaybackHistory,
    );
    sleepTimer = MovementSleepTimer(
      onFadeOutStart: () => _engine.fadeOutAndPause(const Duration(seconds: 20)),
      onTimerEnd: () {}, // fadeOutAndPause above already pauses at zero volume by the time the duration elapses
    );
    _bindEngineStreams();
  }

  void _bindEngineStreams() {
    _positionSub = _engine.positionStream.listen((position) {
      _position = position;
      _broadcastState();
    });
    _playingSub = _engine.playingStream.listen((playing) {
      _playing = playing;
      _broadcastState();
    });
    _durationSub = _engine.durationStream.listen((duration) {
      _duration = duration;
      final current = _queueManager.currentTrack;
      if (current != null) {
        mediaItem.add(MediaItemMapper.fromTrack(current).copyWith(duration: duration));
      }
    });
    _bufferingSub = _engine.bufferingStream.listen((buffering) {
      _buffering = buffering;
      _broadcastState();
    });
    _trackSub = _engine.currentTrackStream.listen((track) {
      if (track != null) {
        mediaItem.add(MediaItemMapper.fromTrack(track));
        _updateQueueBroadcast();
      }
    });
    _sessionIdSub = _engine.audioSessionIdStream.listen((sessionId) {
      equalizer.attachToSession(sessionId);
    });
  }

  void _broadcastState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      playing: _playing,
      updatePosition: _position,
      bufferedPosition: _position,
      speed: 1.0,
      queueIndex: _queueManager.currentOriginalIndex,
    ));
  }

  void _updateQueueBroadcast() {
    queue.add(_queueManager.queueInOriginalOrder.map(MediaItemMapper.fromTrack).toList());
  }

  Future<void> _commitPlaybackHistory(Track track, int msPlayed, bool completedNaturally) async {
    final isar = await IsarService.instance.open();
    await isar.writeTxn(() async {
      final history = PlayHistory()
        ..trackId = track.id
        ..playedAt = DateTime.now()
        ..msPlayed = msPlayed
        ..completed = completedNaturally;
      await isar.playHistorys.put(history);

      // Re-fetch inside the transaction in case another isolate (e.g. a
      // concurrent library re-scan) updated this row since it was loaded
      // into the engine's queue, so the increment applies to current data.
      final freshTrack = await isar.tracks.get(track.id);
      if (freshTrack != null) {
        freshTrack.playCount += 1;
        freshTrack.lastPlayedAt = DateTime.now();
        await isar.tracks.put(freshTrack);
      }
    });
  }

  // ---------------------------------------------------------------------
  // BaseAudioHandler overrides — the actual OS-facing control surface.
  // ---------------------------------------------------------------------
  @override
  Future<void> play() => _engine.play();

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> stop() async {
    await _engine.pause();
    await _engine.seek(Duration.zero);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _engine.seek(position);

  @override
  Future<void> skipToNext() => _engine.skipToNext();

  @override
  Future<void> skipToPrevious() => _engine.skipToPrevious();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _engine.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _engine.setRepeatMode(CraunchRepeatMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _engine.setRepeatMode(CraunchRepeatMode.repeatOne);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _engine.setRepeatMode(CraunchRepeatMode.repeatAll);
        break;
    }
  }

  /// App-specific entry point (not part of BaseAudioHandler) used by the
  /// library UI to start playback of a chosen track within its surrounding
  /// list — e.g. tapping a song in the Songs tab queues the whole visible
  /// list with that song as the start index.
  Future<void> playTrackWithQueue(List<Track> queueTracks, int startIndex) async {
    await _engine.loadAndPlayQueue(queueTracks, startIndex);
    _updateQueueBroadcast();
  }

  Future<void> setCrossfadeSeconds(double seconds) async {
    await _engine.setCrossfadeDuration(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Backing calls for the drag-and-drop queue screen. `fromVisualIndex`/
  /// `toVisualIndex` are indices into [currentQueueInPlayOrder] — i.e.
  /// exactly what the user sees and drags in the UI, shuffle or not.
  List<Track> currentQueueInPlayOrder() => _queueManager.queueInPlayOrder;

  int currentQueuePosition() => _queueManager.currentPlayOrderPosition;

  void reorderQueue(int fromVisualIndex, int toVisualIndex) {
    _queueManager.reorderInPlayOrder(fromVisualIndex, toVisualIndex);
    _updateQueueBroadcast();
  }

  void removeFromQueueAt(int visualIndex) {
    _queueManager.removeAtVisualIndex(visualIndex);
    _updateQueueBroadcast();
  }

  Future<void> onTaskRemoved() async {
    await dispose();
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _playingSub?.cancel();
    await _durationSub?.cancel();
    await _trackSub?.cancel();
    await _bufferingSub?.cancel();
    await _sessionIdSub?.cancel();
    await _engine.dispose();
    await equalizer.detach();
    sleepTimer.dispose();
  }
}
