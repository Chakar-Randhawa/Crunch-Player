/// A single band's live state. [centerFrequencyHz] and the device's actual
/// gain range come from the native side at initialization time — real
/// Android devices report different ranges (commonly ±15dB but sometimes
/// ±12.5dB or ±10dB), so nothing here hardcodes a range; the controller
/// always scales against whatever the attached hardware effect reports.
class EqualizerBand {
  final int index;
  final int centerFrequencyHz;
  double gainDb;

  EqualizerBand({
    required this.index,
    required this.centerFrequencyHz,
    this.gainDb = 0.0,
  });

  String get displayLabel {
    if (centerFrequencyHz >= 1000) {
      final khz = centerFrequencyHz / 1000;
      return khz == khz.roundToDouble() ? '${khz.toInt()}kHz' : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${centerFrequencyHz}Hz';
  }
}

/// Presets are stored as normalized curves in [-1.0, 1.0] per band rather
/// than fixed dB values, then scaled by [EqualizerController] against the
/// device's actual reported gain range when applied. A device with a
/// ±10dB range and one with a ±15dB range should both get a recognizable
/// "Rock" shape, not the same absolute dB numbers clipped differently.
class EqualizerPreset {
  final String name;
  final List<double> normalizedCurve; // one entry per band, [-1, 1]

  const EqualizerPreset(this.name, this.normalizedCurve);

  static const flat = EqualizerPreset('Flat', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

  static const rock = EqualizerPreset(
    'Rock',
    [0.5, 0.35, 0.1, -0.1, -0.15, -0.1, 0.05, 0.25, 0.4, 0.45],
  );

  static const pop = EqualizerPreset(
    'Pop',
    [-0.1, 0.1, 0.3, 0.35, 0.15, -0.05, -0.1, -0.05, 0.05, 0.1],
  );

  static const jazz = EqualizerPreset(
    'Jazz',
    [0.3, 0.2, 0.05, 0.1, -0.1, -0.1, 0.05, 0.2, 0.3, 0.35],
  );

  static const classical = EqualizerPreset(
    'Classical',
    [0.35, 0.3, 0.2, 0.1, 0, 0, -0.05, -0.05, 0.1, 0.25],
  );

  static const bassBoostCurve = EqualizerPreset(
    'Bass Boost',
    [0.9, 0.75, 0.5, 0.2, 0, 0, 0, 0, 0, 0],
  );

  static const vocal = EqualizerPreset(
    'Vocal',
    [-0.2, -0.15, -0.05, 0.15, 0.4, 0.4, 0.25, 0.05, -0.1, -0.15],
  );

  static const trebleBoost = EqualizerPreset(
    'Treble Boost',
    [0, 0, 0, 0, 0, 0.15, 0.35, 0.55, 0.7, 0.8],
  );

  static const all = [flat, rock, pop, jazz, classical, bassBoostCurve, vocal, trebleBoost];
}

enum ReverbPreset { none, smallRoom, mediumRoom, largeRoom, mediumHall, largeHall, plate }

/// Full snapshot of equalizer state as surfaced to the UI. Held by
/// [EqualizerController] and rebuilt (not mutated) on every change so
/// Riverpod/Provider listeners get clean change detection.
class EqualizerState {
  final bool enabled;
  final bool nativeAttached;
  final List<EqualizerBand> bands;
  final double minGainDb;
  final double maxGainDb;
  final String activePresetName; // "Custom" once the user drags a slider
  final int bassBoostStrength; // 0-1000, matches Android BassBoost's native range
  final int virtualizerStrength; // 0-1000, matches Android Virtualizer's native range
  final ReverbPreset reverbPreset;

  const EqualizerState({
    required this.enabled,
    required this.nativeAttached,
    required this.bands,
    required this.minGainDb,
    required this.maxGainDb,
    required this.activePresetName,
    required this.bassBoostStrength,
    required this.virtualizerStrength,
    required this.reverbPreset,
  });

  factory EqualizerState.initial() => const EqualizerState(
        enabled: false,
        nativeAttached: false,
        bands: [],
        minGainDb: -15.0,
        maxGainDb: 15.0,
        activePresetName: 'Flat',
        bassBoostStrength: 0,
        virtualizerStrength: 0,
        reverbPreset: ReverbPreset.none,
      );

  EqualizerState copyWith({
    bool? enabled,
    bool? nativeAttached,
    List<EqualizerBand>? bands,
    double? minGainDb,
    double? maxGainDb,
    String? activePresetName,
    int? bassBoostStrength,
    int? virtualizerStrength,
    ReverbPreset? reverbPreset,
  }) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      nativeAttached: nativeAttached ?? this.nativeAttached,
      bands: bands ?? this.bands,
      minGainDb: minGainDb ?? this.minGainDb,
      maxGainDb: maxGainDb ?? this.maxGainDb,
      activePresetName: activePresetName ?? this.activePresetName,
      bassBoostStrength: bassBoostStrength ?? this.bassBoostStrength,
      virtualizerStrength: virtualizerStrength ?? this.virtualizerStrength,
      reverbPreset: reverbPreset ?? this.reverbPreset,
    );
  }
}
