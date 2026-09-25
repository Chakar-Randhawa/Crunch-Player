package com.craunch.player.demux

/**
 * Loads the native MP3 encoder library on first use. If libmp3lame hasn't
 * been vendored and the CMake build enabled yet (see cpp/CMakeLists.txt),
 * [isAvailable] reports false and every encode call fails with a clear
 * message rather than crashing the whole app on a missing native library.
 */
object Mp3Encoder {
    private var libraryLoaded = false
    private var loadAttempted = false

    val isAvailable: Boolean
        get() {
            if (!loadAttempted) {
                loadAttempted = true
                libraryLoaded = try {
                    System.loadLibrary("craunch_mp3_encoder")
                    true
                } catch (e: UnsatisfiedLinkError) {
                    false
                }
            }
            return libraryLoaded
        }

    fun createSession(sampleRate: Int, channels: Int, bitrateKbps: Int): Mp3EncoderSession? {
        if (!isAvailable) return null
        val handle = nativeInit(sampleRate, channels, bitrateKbps)
        if (handle == 0L) return null
        return Mp3EncoderSession(handle)
    }

    @JvmStatic
    external fun nativeInit(sampleRate: Int, channels: Int, bitrateKbps: Int): Long

    @JvmStatic
    external fun nativeEncodeChunk(
        handlePtr: Long,
        pcmInterleaved: ShortArray,
        frameCount: Int,
        mp3OutBuffer: ByteArray,
        mp3OutBufferSize: Int,
    ): Int

    @JvmStatic
    external fun nativeFlush(handlePtr: Long, mp3OutBuffer: ByteArray, mp3OutBufferSize: Int): Int

    @JvmStatic
    external fun nativeClose(handlePtr: Long)
}

/**
 * One encode session over a single output file. [handle] is a pointer to
 * the native `EncoderHandle` struct — this class's whole job is making
 * sure [close] always runs so that native memory doesn't leak, since Kotlin's
 * GC has no visibility into it.
 */
class Mp3EncoderSession internal constructor(private val handle: Long) : AutoCloseable {
    private val mp3Buffer = ByteArray(1 shl 17) // 128KB — comfortably larger than any single encode call's output

    /** Returns the MP3 bytes produced for this chunk (may be empty — LAME buffers internally). */
    fun encodeChunk(pcmInterleaved: ShortArray, frameCount: Int): ByteArray {
        val written = Mp3Encoder.nativeEncodeChunk(handle, pcmInterleaved, frameCount, mp3Buffer, mp3Buffer.size)
        if (written < 0) throw IllegalStateException("LAME encode_buffer_interleaved failed: $written")
        return mp3Buffer.copyOf(written)
    }

    fun flush(): ByteArray {
        val written = Mp3Encoder.nativeFlush(handle, mp3Buffer, mp3Buffer.size)
        if (written < 0) throw IllegalStateException("LAME encode_flush failed: $written")
        return mp3Buffer.copyOf(written)
    }

    override fun close() {
        Mp3Encoder.nativeClose(handle)
    }
}
