// lame_jni.cpp
//
// ============================================================================
// REQUIRED SETUP — read before building
// ============================================================================
// This file is a real, complete JNI bridge to libmp3lame's public C API
// (lame_init / lame_encode_buffer_interleaved / lame_encode_flush /
// lame_close). It is NOT self-sufficient on its own: libmp3lame itself —
// the actual MP3 encoder — is a ~15,000-line third-party C codebase (the
// LAME project, lame.sourceforge.io, LGPL-licensed) that must be vendored
// into android/app/src/main/cpp/lame/ (or linked as a prebuilt .a/.so)
// before CMakeLists.txt below can produce a working library.
//
// This is the same category of gap as the ONNX model weights in the stem
// separation module: neither Android nor iOS ships a system MP3 encoder
// (only decoders), so any app doing real MP3 encoding — not just this
// one — either vendors LAME or an equivalent codec, or links a prebuilt
// binary. Reproducing LAME's full source inline here isn't something a
// single file can honestly claim to do; what this file provides is the
// correct, complete bridge code for whichever copy of libmp3lame gets
// vendored.
// ============================================================================

#include <jni.h>
#include <cstdlib>
#include <cstring>
#include <lame/lame.h>

struct EncoderHandle {
    lame_global_flags *gfp;
};

extern "C" JNIEXPORT jlong JNICALL
Java_com_craunch_player_demux_Mp3Encoder_nativeInit(
        JNIEnv *env, jobject /* thiz */,
        jint sampleRate, jint channels, jint bitrateKbps) {
    lame_global_flags *gfp = lame_init();
    if (gfp == nullptr) return 0;

    lame_set_in_samplerate(gfp, sampleRate);
    lame_set_num_channels(gfp, channels);
    lame_set_brate(gfp, bitrateKbps);
    lame_set_quality(gfp, 2); // 0 = best/slowest, 9 = worst/fastest; 2 is a standard high-quality default
    lame_set_mode(gfp, channels == 1 ? MONO : JOINT_STEREO);

    if (lame_init_params(gfp) < 0) {
        lame_close(gfp);
        return 0;
    }

    auto *handle = new EncoderHandle{gfp};
    return reinterpret_cast<jlong>(handle);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_craunch_player_demux_Mp3Encoder_nativeEncodeChunk(
        JNIEnv *env, jobject /* thiz */,
        jlong handlePtr, jshortArray pcmInterleaved, jint frameCount,
        jbyteArray mp3OutBuffer, jint mp3OutBufferSize) {
    auto *handle = reinterpret_cast<EncoderHandle *>(handlePtr);
    if (handle == nullptr) return -1;

    jshort *pcm = env->GetShortArrayElements(pcmInterleaved, nullptr);
    jbyte *mp3Out = env->GetByteArrayElements(mp3OutBuffer, nullptr);

    // lame_encode_buffer_interleaved expects interleaved 16-bit PCM for
    // stereo input; for mono input LAME treats the same buffer as a
    // single channel stream, which lame_set_num_channels above already
    // configured this encoder instance for.
    int bytesWritten = lame_encode_buffer_interleaved(
            handle->gfp,
            reinterpret_cast<short int *>(pcm),
            frameCount,
            reinterpret_cast<unsigned char *>(mp3Out),
            mp3OutBufferSize);

    env->ReleaseShortArrayElements(pcmInterleaved, pcm, JNI_ABORT);
    env->ReleaseByteArrayElements(mp3OutBuffer, mp3Out, 0);

    return bytesWritten;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_craunch_player_demux_Mp3Encoder_nativeFlush(
        JNIEnv *env, jobject /* thiz */,
        jlong handlePtr, jbyteArray mp3OutBuffer, jint mp3OutBufferSize) {
    auto *handle = reinterpret_cast<EncoderHandle *>(handlePtr);
    if (handle == nullptr) return -1;

    jbyte *mp3Out = env->GetByteArrayElements(mp3OutBuffer, nullptr);
    int bytesWritten = lame_encode_flush(
            handle->gfp,
            reinterpret_cast<unsigned char *>(mp3Out),
            mp3OutBufferSize);
    env->ReleaseByteArrayElements(mp3OutBuffer, mp3Out, 0);

    return bytesWritten;
}

extern "C" JNIEXPORT void JNICALL
Java_com_craunch_player_demux_Mp3Encoder_nativeClose(
        JNIEnv *env, jobject /* thiz */, jlong handlePtr) {
    auto *handle = reinterpret_cast<EncoderHandle *>(handlePtr);
    if (handle == nullptr) return;
    lame_close(handle->gfp);
    delete handle;
}
