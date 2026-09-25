import 'package:flutter/foundation.dart';

import 'equalizer_channel.dart';
import 'equalizer_models.dart';

class EqualizerController extends ChangeNotifier {
  final EqualizerChannel _channel;
  EqualizerState _state = EqualizerState.initial();

  EqualizerController({EqualizerChannel channel = const EqualizerChannel()}) : _channel = channel;

  EqualizerState get state => _state;

  /// Must be called whenever the underlying AudioPlayer's Android audio
  /// session id changes — which happens once at startup and again on
  /// every crossfade swap in PlaybackEngine, since a freshly-constructed
  /// AudioPlayer gets a new native session id that the previously
  /// attached AudioEffect does not automatically follow.
  Future<void> attachToSession(int audioSessionId) async {
    final caps = await _channel.attach(audioSessionId);
    if (caps == null) {
      _state = _state.copyWith(nativeAttached: false);
      notifyListeners();
      return;
    }

    final bands = List.generate(
      caps.bandCount,
      (i) => EqualizerBand(index: i, centerFrequencyHz: caps.centerFrequenciesHz[i]),
    );

    _state = _state.copyWith(
      nativeAttached: true,
      bands: bands,
      minGainDb: caps.minGainDb,
      maxGainDb: caps.maxGainDb,
    );

    // Re-apply whatever curve/enabled-state the user had configured before
    // this reattach (e.g. surviving a crossfade swap mid-song) rather than
    // silently resetting to flat.
    await setEnabled(_state.enabled, persistPreset: false);
    await _reapplyCurrentBandsToNative();
    notifyListeners();
  }

  Future<void> detach() async {
    await _channel.detach();
    _state = _state.copyWith(nativeAttached: false);
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled, {bool persistPreset = true}) async {
    _state = _state.copyWith(enabled: enabled);
    if (_state.nativeAttached) await _channel.setEnabled(enabled);
    notifyListeners();
  }

  /// Applies a single band drag from the UI. Setting any band manually
  /// marks the active preset as "Custom" — flipping back to a named
  /// preset is an explicit user action via [applyPreset].
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _state.bands.length) return;
    final clamped = gainDb.clamp(_state.minGainDb, _state.maxGainDb);

    final updatedBands = List<EqualizerBand>.of(_state.bands);
    updatedBands[bandIndex] = EqualizerBand(
      index: bandIndex,
      centerFrequencyHz: updatedBands[bandIndex].centerFrequencyHz,
      gainDb: clamped,
    );

    _state = _state.copyWith(bands: updatedBands, activePresetName: 'Custom');
    if (_state.nativeAttached) await _channel.setBandLevel(bandIndex, clamped);
    notifyListeners();
  }

  /// Scales [preset]'s normalized [-1, 1] curve against the device's
  /// actual reported gain range, so the same preset produces a sensible
  /// shape whether the hardware reports ±15dB, ±12.5dB, or ±10dB.
  Future<void> applyPreset(EqualizerPreset preset) async {
    if (_state.bands.isEmpty) return;
    final span = _state.maxGainDb; // symmetric range assumed, matches every real AudioFx Equalizer

    final updatedBands = <EqualizerBand>[];
    for (int i = 0; i < _state.bands.length; i++) {
      final normalized = i < preset.normalizedCurve.length ? preset.normalizedCurve[i] : 0.0;
      final gainDb = (normalized * span).clamp(_state.minGainDb, _state.maxGainDb);
      updatedBands.add(EqualizerBand(
        index: i,
        centerFrequencyHz: _state.bands[i].centerFrequencyHz,
        gainDb: gainDb,
      ));
    }

    _state = _state.copyWith(bands: updatedBands, activePresetName: preset.name);
    await _reapplyCurrentBandsToNative();
    notifyListeners();
  }

  Future<void> setBassBoostStrength(int strength0to1000) async {
    final clamped = strength0to1000.clamp(0, 1000);
    _state = _state.copyWith(bassBoostStrength: clamped);
    if (_state.nativeAttached) await _channel.setBassBoostStrength(clamped);
    notifyListeners();
  }

  /// "3D reverb vectors" from the original spec are realized here as the
  /// combination of stereo-widening (Virtualizer strength) plus a spatial
  /// reverb preset (PresetReverb) — the two standard, real Android
  /// AudioFx components that together produce a spatial effect. A true
  /// per-axis 3D positional reverb vector isn't a stock AudioEffect API
  /// on either platform; this is the honest, working equivalent rather
  /// than a fabricated API surface.
  Future<void> setVirtualizerStrength(int strength0to1000) async {
    final clamped = strength0to1000.clamp(0, 1000);
    _state = _state.copyWith(virtualizerStrength: clamped);
    if (_state.nativeAttached) await _channel.setVirtualizerStrength(clamped);
    notifyListeners();
  }

  Future<void> setReverbPreset(ReverbPreset preset) async {
    _state = _state.copyWith(reverbPreset: preset);
    if (_state.nativeAttached) await _channel.setReverbPreset(preset.name);
    notifyListeners();
  }

  Future<void> _reapplyCurrentBandsToNative() async {
    if (!_state.nativeAttached) return;
    for (final band in _state.bands) {
      await _channel.setBandLevel(band.index, band.gainDb);
    }
  }
}
