package com.craunch.player.equalizer

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CraunchEqualizerPlugin : FlutterPlugin, MethodCallHandler {

    private var channel: MethodChannel? = null
    private var engine: CraunchEqualizerEngine? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engine?.release()
        engine = null
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "attach" -> {
                    // Releasing any previous engine before attaching a new
                    // one is required, not optional — Android's AudioFx
                    // effects are tied to one session id for their whole
                    // lifetime, and this is the point where PlaybackEngine
                    // has told us that id just changed (a crossfade swap
                    // created a new ExoPlayer instance under the hood).
                    engine?.release()
                    val sessionId = (call.argument<Int>("audioSessionId"))
                        ?: return result.error("BAD_ARGS", "audioSessionId is required", null)

                    val newEngine = CraunchEqualizerEngine(sessionId)
                    val caps = newEngine.attach()
                    engine = newEngine

                    result.success(
                        mapOf(
                            "bandCount" to caps.bandCount,
                            "centerFrequenciesHz" to caps.centerFrequenciesHz,
                            "minGainDb" to caps.minGainDb,
                            "maxGainDb" to caps.maxGainDb,
                        )
                    )
                }

                "detach" -> {
                    engine?.release()
                    engine = null
                    result.success(null)
                }

                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine?.setEnabled(enabled)
                    result.success(null)
                }

                "setBandLevel" -> {
                    val bandIndex = call.argument<Int>("bandIndex")
                        ?: return result.error("BAD_ARGS", "bandIndex is required", null)
                    val gainDb = call.argument<Double>("gainDb")
                        ?: return result.error("BAD_ARGS", "gainDb is required", null)
                    engine?.setBandLevel(bandIndex, gainDb)
                    result.success(null)
                }

                "setBassBoostStrength" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    engine?.setBassBoostStrength(strength)
                    result.success(null)
                }

                "setVirtualizerStrength" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    engine?.setVirtualizerStrength(strength)
                    result.success(null)
                }

                "setReverbPreset" -> {
                    val preset = call.argument<String>("preset") ?: "none"
                    engine?.setReverbPreset(preset)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // A denied/unsupported AudioFx feature on a given OEM's device
            // (some manufacturers restrict certain effects) surfaces here
            // as an exception rather than crashing the platform channel —
            // the Dart side already treats any PlatformException as "no
            // native equalizer available" and degrades gracefully.
            result.error("EQUALIZER_ERROR", e.message, null)
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.craunch.player/equalizer"
    }
}
