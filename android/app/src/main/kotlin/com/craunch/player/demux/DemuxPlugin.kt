package com.craunch.player.demux

import android.os.Handler
import android.os.Looper
import com.craunch.player.pcm.PcmDecoder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.Executors

class DemuxPlugin : FlutterPlugin, MethodCallHandler {

    private var channel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.craunch.player/demux")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "extractInstant" -> handleInstantExtract(call, result)
            "isMp3EncoderAvailable" -> result.success(Mp3Encoder.isAvailable)
            "transcodeToMp3" -> handleTranscodeToMp3(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleInstantExtract(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
            ?: return result.error("BAD_ARGS", "inputPath is required", null)
        val outputPath = call.argument<String>("outputPath")
            ?: return result.error("BAD_ARGS", "outputPath is required", null)

        executor.execute {
            try {
                val demuxResult = InstantAudioDemuxer().extract(inputPath, outputPath)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "outputPath" to demuxResult.outputPath,
                            "mimeType" to demuxResult.mimeType,
                            "durationUs" to demuxResult.durationUs,
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("DEMUX_ERROR", e.message, null) }
            }
        }
    }

    private fun handleTranscodeToMp3(call: MethodCall, result: Result) {
        if (!Mp3Encoder.isAvailable) {
            result.error(
                "ENCODER_NOT_BUILT",
                "The native MP3 encoder isn't built into this app yet. See " +
                    "android/app/src/main/cpp/lame_jni.cpp and CMakeLists.txt for the " +
                    "vendoring steps, then uncomment the externalNativeBuild block in " +
                    "app/build.gradle. The instant-demux (.m4a) path works without this.",
                null,
            )
            return
        }

        val inputPath = call.argument<String>("inputPath")
            ?: return result.error("BAD_ARGS", "inputPath is required", null)
        val outputPath = call.argument<String>("outputPath")
            ?: return result.error("BAD_ARGS", "outputPath is required", null)
        val bitrateKbps = call.argument<Int>("bitrateKbps") ?: 192

        executor.execute {
            var pcmTempFile: File? = null
            try {
                pcmTempFile = File.createTempFile("craunch_transcode_", ".wav")
                val decodeResult = PcmDecoder().decodeToPcmWav(inputPath, pcmTempFile.absolutePath)

                val session = Mp3Encoder.createSession(
                    decodeResult.sampleRate,
                    decodeResult.channelCount,
                    bitrateKbps,
                ) ?: throw IllegalStateException("Mp3Encoder.createSession returned null")

                session.use { encoder ->
                    RandomAccessFile(pcmTempFile, "r").use { pcmFile ->
                        RandomAccessFile(outputPath, "rw").use { mp3File ->
                            pcmFile.seek(44) // skip the WAV header PcmDecoder.kt wrote
                            val frameSize = decodeResult.channelCount * 2 // 16-bit samples
                            val framesPerChunk = 8192
                            val chunkBytes = ByteArray(framesPerChunk * frameSize)

                            while (true) {
                                val bytesRead = pcmFile.read(chunkBytes)
                                if (bytesRead <= 0) break

                                val frameCount = bytesRead / frameSize
                                val shorts = ShortArray(frameCount * decodeResult.channelCount)
                                for (i in shorts.indices) {
                                    val byteOffset = i * 2
                                    shorts[i] = ((chunkBytes[byteOffset].toInt() and 0xFF) or
                                        (chunkBytes[byteOffset + 1].toInt() shl 8)).toShort()
                                }

                                val mp3Chunk = encoder.encodeChunk(shorts, frameCount)
                                if (mp3Chunk.isNotEmpty()) mp3File.write(mp3Chunk)
                            }

                            val flushed = encoder.flush()
                            if (flushed.isNotEmpty()) mp3File.write(flushed)
                        }
                    }
                }

                mainHandler.post {
                    result.success(mapOf("outputPath" to outputPath))
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("TRANSCODE_ERROR", e.message, null) }
            } finally {
                pcmTempFile?.delete()
            }
        }
    }
}
