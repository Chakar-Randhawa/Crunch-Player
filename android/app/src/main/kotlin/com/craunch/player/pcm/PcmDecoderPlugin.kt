package com.craunch.player.pcm

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

class PcmDecoderPlugin : FlutterPlugin, MethodCallHandler {

    private var channel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.craunch.player/pcmdecoder")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "decodeToPcm") {
            result.notImplemented()
            return
        }

        val inputPath = call.argument<String>("inputPath")
            ?: return result.error("BAD_ARGS", "inputPath is required", null)
        val outputPath = call.argument<String>("outputPath")
            ?: return result.error("BAD_ARGS", "outputPath is required", null)

        // MediaCodec decoding is blocking and can take real wall-clock time
        // for a several-minute song, so this runs off the platform
        // channel's own thread — returning the result via mainHandler.post
        // is required because Flutter's Result callback must be invoked
        // on the platform thread the call arrived on.
        executor.execute {
            try {
                val decodeResult = PcmDecoder().decodeToPcmWav(inputPath, outputPath)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "pcmFilePath" to decodeResult.pcmFilePath,
                            "sampleRate" to decodeResult.sampleRate,
                            "channelCount" to decodeResult.channelCount,
                            "totalFrames" to decodeResult.totalFrames,
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DECODE_ERROR", e.message, null)
                }
            }
        }
    }
}
