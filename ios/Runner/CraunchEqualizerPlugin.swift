import Flutter
import UIKit

/// Registers the same `com.craunch.player/equalizer` channel the Android
/// side implements, but with a materially different `attach` behavior —
/// documented here rather than glossed over.
///
/// **Real architectural constraint:** just_audio's iOS implementation
/// plays audio through AVPlayer/AVQueuePlayer, which has no public tap
/// point for inserting an AVAudioUnitEQ node the way Android's ExoPlayer
/// exposes an audio session id that `android.media.audiofx.Equalizer` can
/// attach to. AVAudioEngineEqualizer.swift alongside this file is a fully
/// working 10-band EQ, but it operates on its own AVAudioEngine graph —
/// wiring actual song playback through it (replacing just_audio's iOS
/// AVPlayer path with an AVAudioPlayerNode-driven one, or inserting an
/// MTAudioProcessingTap on the existing AVPlayerItem) is a materially
/// larger change than this method channel alone, since it changes how
/// audio is decoded and scheduled, not just how it's filtered.
///
/// Rather than report fake capabilities that would make band sliders
/// appear to work while doing nothing audible, `attach` returns an error
/// so the Dart-side EqualizerController degrades to "no native EQ
/// available" on iOS — an honest state the UI can surface (e.g. graying
/// out the equalizer screen with an explanatory note) instead of a
/// control that silently has no effect.
class CraunchEqualizerPlugin: NSObject, FlutterPlugin {

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.craunch.player/equalizer",
            binaryMessenger: controller.binaryMessenger
        )
        let instance = CraunchEqualizerPlugin()
        channel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "attach":
            result(FlutterError(
                code: "UNSUPPORTED_PLAYBACK_PATH",
                message: "The native equalizer requires routing playback through an " +
                    "AVAudioEngine graph; just_audio's current iOS backend (AVPlayer) " +
                    "does not expose a tap point for this yet. See " +
                    "AVAudioEngineEqualizer.swift for the working EQ implementation " +
                    "pending that integration.",
                details: nil
            ))
        case "detach", "setEnabled", "setBandLevel", "setBassBoostStrength",
             "setVirtualizerStrength", "setReverbPreset":
            // No-ops rather than errors once already detached/never
            // attached — mirrors the Android side's "detaching an
            // already-detached effect is harmless" behavior, and avoids
            // spamming errors for calls that only fire because the Dart
            // controller doesn't special-case "iOS has no native EQ" at
            // every call site.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
