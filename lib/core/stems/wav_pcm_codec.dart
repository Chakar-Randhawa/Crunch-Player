import 'dart:io';
import 'dart:typed_data';

class WavPcmData {
  final Float32List samples; // interleaved if multi-channel, normalized to [-1.0, 1.0]
  final int sampleRate;
  final int channelCount;

  const WavPcmData({required this.samples, required this.sampleRate, required this.channelCount});
}

/// Minimal 16-bit PCM WAV reader/writer. Deliberately narrow in scope —
/// this only needs to round-trip the exact format PcmDecoder.kt produces
/// (16-bit signed little-endian PCM), not arbitrary WAV variants.
class WavPcmCodec {
  const WavPcmCodec();

  Future<WavPcmData> read(String path) async {
    final bytes = await File(path).readAsBytes();
    final data = ByteData.sublistView(bytes);

    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      throw FormatException('Not a valid WAV file: $path');
    }

    final channelCount = data.getUint16(22, Endian.little);
    final sampleRate = data.getUint32(24, Endian.little);
    final bitsPerSample = data.getUint16(34, Endian.little);
    if (bitsPerSample != 16) {
      throw UnsupportedError('Only 16-bit PCM WAV is supported, got $bitsPerSample-bit');
    }

    // Locate the 'data' chunk rather than assuming it starts at byte 44 —
    // some encoders insert extra chunks (e.g. a 'fact' chunk) before it.
    int offset = 12;
    int dataOffset = -1;
    int dataSize = 0;
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = chunkSize;
        break;
      }
      offset += 8 + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (dataOffset == -1) throw FormatException('No data chunk found in $path');

    final sampleCount = dataSize ~/ 2;
    final samples = Float32List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      final raw = data.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = raw / 32768.0;
    }

    return WavPcmData(samples: samples, sampleRate: sampleRate, channelCount: channelCount);
  }

  Future<void> write(String path, WavPcmData pcm) async {
    final sampleCount = pcm.samples.length;
    final dataSize = sampleCount * 2;
    final byteRate = pcm.sampleRate * pcm.channelCount * 2;
    final blockAlign = pcm.channelCount * 2;

    final buffer = ByteData(44 + dataSize);
    void putString(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        buffer.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    putString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    putString(8, 'WAVE');
    putString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, pcm.channelCount, Endian.little);
    buffer.setUint32(24, pcm.sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    putString(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < sampleCount; i++) {
      final clamped = pcm.samples[i].clamp(-1.0, 1.0);
      final intValue = (clamped * 32767.0).round();
      buffer.setInt16(44 + i * 2, intValue, Endian.little);
    }

    await File(path).writeAsBytes(buffer.buffer.asUint8List(), flush: true);
  }
}
