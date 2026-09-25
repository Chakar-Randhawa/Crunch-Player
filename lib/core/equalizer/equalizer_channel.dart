import 'dart:io';
import 'package:flutter/services.dart';

/// Raw device capabilities and current values reported back after
/// attaching the native equalizer effect to a given audio session.
class NativeEqualizerCapabilities {
  final int bandCount;
  final List<int> centerFrequenciesHz;
  final double minGainDb;
  final double maxGainDb;

  const NativeEqualizerCapabilities({
    required this.bandCount,
    required this.centerFrequenciesHz,
    required this.minGainDb,
    required this.maxGainDb,
  });

  factory NativeEqualizerCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return NativeEqualizerCapabilities(
      bandCount: map['bandCount'] as int,
      centerFrequenciesHz: List<int>.from(map['centerFrequenciesHz'] as List),
      minGainDb: (map['minGainDb'] as num).toDouble(),
      maxGainDb: (map['maxGainDb'] as num).toDouble(),
    );
  }
}

/// Wraps the platform channel used to control the native
/// Equalizer/BassBoost/Virtualizer/PresetReverb audio effects (Android) or
/// the AVAudioEngine EQ graph (iOS — see the iOS module's integration note
/// for the current limitation on wiring this to just_audio's playback
/// path). Every method is a no-op returning a sensible default on
/// platforms with no native implementation registered, so callers never
/// need their own platform checks.
class EqualizerChannel {
  static const MethodChannel _channel = MethodChannel('com.craunch.player/equalizer');

  const EqualizerChannel();

  bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  Future<NativeEqualizerCapabilities?> attach(int audioSessionId) async {
    if (!isSupportedPlatform) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'attach',
        {'audioSessionId': audioSessionId},
      );
      if (result == null) return null;
      return NativeEqualizerCapabilities.fromMap(result);
    } on PlatformException {
      return null;
    }
  }

  Future<void> detach() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod('detach');
    } on PlatformException {
      // Detaching an already-detached effect is harmless to ignore.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('setEnabled', {'enabled': enabled});
  }

  Future<void> setBandLevel(int bandIndex, double gainDb) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('setBandLevel', {
      'bandIndex': bandIndex,
      'gainDb': gainDb,
    });
  }

  Future<void> setBassBoostStrength(int strength0to1000) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('setBassBoostStrength', {'strength': strength0to1000});
  }

  Future<void> setVirtualizerStrength(int strength0to1000) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('setVirtualizerStrength', {'strength': strength0to1000});
  }

  Future<void> setReverbPreset(String presetKey) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('setReverbPreset', {'preset': presetKey});
  }
}
