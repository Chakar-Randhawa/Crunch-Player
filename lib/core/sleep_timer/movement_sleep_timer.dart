import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

enum SleepTimerMode { off, fixedDuration, movementBased }

class SleepTimerState {
  final SleepTimerMode mode;
  final Duration? remaining; // meaningful for fixedDuration mode
  final Duration stillDuration; // meaningful for movementBased mode — how long stillness has held
  final bool fadingOut;

  const SleepTimerState({
    required this.mode,
    this.remaining,
    this.stillDuration = Duration.zero,
    this.fadingOut = false,
  });

  static const off = SleepTimerState(mode: SleepTimerMode.off);
}

/// Two independent ways to end a listening session automatically:
///
/// - [startFixedDuration]: the conventional "stop in N minutes" timer.
/// - [startMovementBased]: monitors the accelerometer and stops playback
///   once the device has been resting still (not just "the app is in the
///   background" — a phone actually stationary on a nightstand) for a
///   configured duration, on the theory that stopped movement correlates
///   with the person having fallen asleep. This does not, and cannot,
///   detect sleep itself — it detects device stillness, which is what the
///   accelerometer can actually measure; the docstring on
///   [movementSensitivityThreshold] is explicit about that distinction so
///   callers don't oversell it in UI copy.
class MovementSleepTimer {
  final void Function() onFadeOutStart;
  final void Function() onTimerEnd;
  final Duration Function() currentFadeOutDuration;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _fixedDurationTicker;
  Timer? _stillnessCheckTimer;

  final _stateController = StreamController<SleepTimerState>.broadcast();
  Stream<SleepTimerState> get stateStream => _stateController.stream;

  SleepTimerState _state = SleepTimerState.off;

  // Rolling window of recent acceleration-magnitude samples, used to
  // compute variance — a phone lying still still reads ~9.8 m/s² from
  // gravity, so stillness is "low variance", not "near-zero magnitude".
  final List<double> _magnitudeWindow = [];
  static const int _windowSize = 50; // ~2.5s of samples at a typical ~20Hz sensor rate
  DateTime? _stillSince;

  /// Below this variance (in (m/s²)²), the device is considered "still"
  /// for this feature's purposes — an empirically reasonable threshold
  /// for "resting on a surface, not being held or walked with", not a
  /// claim about detecting sleep itself.
  double movementSensitivityThreshold = 0.15;

  Duration requiredStillDuration = const Duration(minutes: 10);
  Duration fixedFadeOutDuration = const Duration(seconds: 20);

  MovementSleepTimer({
    required this.onFadeOutStart,
    required this.onTimerEnd,
    Duration Function()? currentFadeOutDuration,
  }) : currentFadeOutDuration = currentFadeOutDuration ?? (() => const Duration(seconds: 20));

  void startFixedDuration(Duration duration) {
    cancel();
    var remaining = duration;
    _updateState(SleepTimerState(mode: SleepTimerMode.fixedDuration, remaining: remaining));

    _fixedDurationTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= currentFadeOutDuration() && !_state.fadingOut) {
        onFadeOutStart();
        _updateState(_state.copyWithFading(remaining));
      } else {
        _updateState(SleepTimerState(mode: SleepTimerMode.fixedDuration, remaining: remaining));
      }

      if (remaining <= Duration.zero) {
        timer.cancel();
        onTimerEnd();
        _updateState(SleepTimerState.off);
      }
    });
  }

  void startMovementBased() {
    cancel();
    _magnitudeWindow.clear();
    _stillSince = null;
    _updateState(const SleepTimerState(mode: SleepTimerMode.movementBased));

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_handleAccelerometerEvent);

    // Evaluated on its own timer (rather than on every raw sensor event)
    // so the "how long has it been still" state update rate is
    // predictable regardless of the sensor's actual reporting frequency.
    _stillnessCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) => _evaluateStillness());
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _magnitudeWindow.add(magnitude);
    if (_magnitudeWindow.length > _windowSize) {
      _magnitudeWindow.removeAt(0);
    }
  }

  void _evaluateStillness() {
    if (_magnitudeWindow.length < _windowSize) return; // not enough samples yet to judge

    final mean = _magnitudeWindow.reduce((a, b) => a + b) / _magnitudeWindow.length;
    final variance = _magnitudeWindow.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
        _magnitudeWindow.length;

    final isStillNow = variance < movementSensitivityThreshold;
    final now = DateTime.now();

    if (isStillNow) {
      _stillSince ??= now;
    } else {
      _stillSince = null; // any detected movement resets the still-duration clock entirely
    }

    final stillDuration = _stillSince == null ? Duration.zero : now.difference(_stillSince!);
    final fadeThresholdReached = stillDuration >= requiredStillDuration - currentFadeOutDuration();

    if (fadeThresholdReached && !_state.fadingOut) {
      onFadeOutStart();
    }

    _updateState(SleepTimerState(
      mode: SleepTimerMode.movementBased,
      stillDuration: stillDuration,
      fadingOut: fadeThresholdReached,
    ));

    if (stillDuration >= requiredStillDuration) {
      onTimerEnd();
      cancel();
    }
  }

  void cancel() {
    _accelSub?.cancel();
    _accelSub = null;
    _fixedDurationTicker?.cancel();
    _fixedDurationTicker = null;
    _stillnessCheckTimer?.cancel();
    _stillnessCheckTimer = null;
    _magnitudeWindow.clear();
    _stillSince = null;
    _updateState(SleepTimerState.off);
  }

  void _updateState(SleepTimerState state) {
    _state = state;
    _stateController.add(state);
  }

  void dispose() {
    cancel();
    _stateController.close();
  }
}

extension on SleepTimerState {
  SleepTimerState copyWithFading(Duration remaining) => SleepTimerState(
        mode: mode,
        remaining: remaining,
        stillDuration: stillDuration,
        fadingOut: true,
      );
}
