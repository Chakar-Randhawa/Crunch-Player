package com.craunch.player.pcm

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

data class PcmDecodeResult(
    val pcmFilePath: String,
    val sampleRate: Int,
    val channelCount: Int,
    val totalFrames: Long,
)

/**
 * Decodes the first audio track of [inputPath] (any format the platform's
 * MediaCodec supports — MP3, AAC/M4A, FLAC, OGG, WAV) to a raw 16-bit
 * little-endian PCM WAV file. This is the real decode step the stem
 * separation pipeline needs before it can run STFT/model inference —
 * ONNX models operate on raw sample arrays, not compressed bitstreams.
 */
class PcmDecoder {

    fun decodeToPcmWav(inputPath: String, outputPath: String): PcmDecodeResult {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        var audioTrackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val trackFormat = extractor.getTrackFormat(i)
            val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                format = trackFormat
                break
            }
        }

        requireNotNull(format) { "No audio track found in $inputPath" }
        extractor.selectTrack(audioTrackIndex)

        val mime = format.getString(MediaFormat.KEY_MIME)!!
        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val outputFile = File(outputPath)
        // WAV needs its header (with the final data size) written after
        // the PCM payload is known, so this writes 44 placeholder header
        // bytes now and patches them in once decoding finishes below.
        val raf = RandomAccessFile(outputFile, "rw")
        raf.write(ByteArray(44))

        val bufferInfo = MediaCodec.BufferInfo()
        var sawInputEnd = false
        var sawOutputEnd = false
        var totalPcmBytes = 0L

        while (!sawOutputEnd) {
            if (!sawInputEnd) {
                val inputBufferIndex = codec.dequeueInputBuffer(10_000)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputBufferIndex)!!
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        sawInputEnd = true
                    } else {
                        val presentationTimeUs = extractor.sampleTime
                        codec.queueInputBuffer(inputBufferIndex, 0, sampleSize, presentationTimeUs, 0)
                        extractor.advance()
                    }
                }
            }

            val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
            if (outputBufferIndex >= 0) {
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    sawOutputEnd = true
                }
                if (bufferInfo.size > 0) {
                    val outputBuffer = codec.getOutputBuffer(outputBufferIndex)!!
                    outputBuffer.position(bufferInfo.offset)
                    outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                    val chunk = ByteArray(bufferInfo.size)
                    outputBuffer.get(chunk)
                    raf.write(chunk)
                    totalPcmBytes += chunk.size
                }
                codec.releaseOutputBuffer(outputBufferIndex, false)
            }
        }

        codec.stop()
        codec.release()
        extractor.release()

        writeWavHeader(raf, totalPcmBytes, sampleRate, channelCount)
        raf.close()

        val bytesPerFrame = channelCount * 2 // 16-bit PCM
        val totalFrames = totalPcmBytes / bytesPerFrame

        return PcmDecodeResult(outputPath, sampleRate, channelCount, totalFrames)
    }

    private fun writeWavHeader(raf: RandomAccessFile, pcmDataSize: Long, sampleRate: Int, channelCount: Int) {
        val byteRate = sampleRate * channelCount * 2
        val blockAlign = channelCount * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray())
        header.putInt((36 + pcmDataSize).toInt())
        header.put("WAVE".toByteArray())
        header.put("fmt ".toByteArray())
        header.putInt(16) // PCM fmt chunk size
        header.putShort(1) // audio format: 1 = PCM
        header.putShort(channelCount.toShort())
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort(blockAlign.toShort())
        header.putShort(16) // bits per sample
        header.put("data".toByteArray())
        header.putInt(pcmDataSize.toInt())

        raf.seek(0)
        raf.write(header.array())
    }
}
