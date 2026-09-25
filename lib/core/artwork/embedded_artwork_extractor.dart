import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EmbeddedArtworkResult {
  final Uint8List? bytes;
  final String? mimeType;
  const EmbeddedArtworkResult({this.bytes, this.mimeType});

  bool get hasArtwork => bytes != null && bytes!.isNotEmpty;
  static const none = EmbeddedArtworkResult();
}

/// Reads only the embedded cover image out of a track file. Kept separate
/// from AudioTagReader (which handles title/artist/duration) since
/// artwork extraction is comparatively expensive — decoding a full image
/// — and is only ever needed lazily, on demand for the currently playing
/// track and its album, not for every file during a full library scan.
class EmbeddedArtworkExtractor {
  const EmbeddedArtworkExtractor();

  Future<EmbeddedArtworkResult> extract(File file, String extension) async {
    switch (extension) {
      case 'mp3':
        return _extractFromId3(file);
      case 'm4a':
      case 'aac':
        return _extractFromMp4(file);
      case 'flac':
        return _extractFromFlac(file);
      default:
        return EmbeddedArtworkResult.none;
    }
  }

  // ---------------------------------------------------------------------
  // MP3 — the APIC frame within the ID3v2 header.
  // ---------------------------------------------------------------------
  Future<EmbeddedArtworkResult> _extractFromId3(File file) async {
    final raf = await file.open();
    try {
      final header = await _readBytes(raf, 0, 10);
      if (header.length < 10 || header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
        return EmbeddedArtworkResult.none;
      }

      final majorVersion = header[3];
      final tagSize = _synchsafeToInt(header.sublist(6, 10));
      final tagBytes = await _readBytes(raf, 0, 10 + tagSize);
      var body = tagBytes.sublist(10);

      final unsynchronized = (header[5] & 0x80) != 0;
      if (unsynchronized) body = _removeUnsynchronization(body);

      final idLength = majorVersion == 2 ? 3 : 4;
      int offset = 0;

      while (offset + idLength + (majorVersion == 2 ? 3 : 4) < body.length) {
        final idBytes = body.sublist(offset, offset + idLength);
        if (idBytes.every((b) => b == 0)) break;
        final frameId = ascii.decode(idBytes, allowInvalid: true);
        offset += idLength;

        int frameSize;
        if (majorVersion == 2) {
          frameSize = (body[offset] << 16) | (body[offset + 1] << 8) | body[offset + 2];
          offset += 3;
        } else {
          final sizeBytes = body.sublist(offset, offset + 4);
          frameSize = majorVersion >= 4
              ? _synchsafeToInt(sizeBytes)
              : ByteData.sublistView(sizeBytes).getUint32(0, Endian.big);
          offset += 4 + 2;
        }

        if (frameSize <= 0 || offset + frameSize > body.length) break;
        final frameBody = body.sublist(offset, offset + frameSize);
        offset += frameSize;

        if (frameId == 'APIC' || frameId == 'PIC') {
          return _parseApicFrame(frameBody, isCompactForm: frameId == 'PIC');
        }
      }
      return EmbeddedArtworkResult.none;
    } finally {
      await raf.close();
    }
  }

  /// APIC layout: encoding(1) + MIME type (null-terminated, or 3-char code
  /// for the old "PIC" frame) + picture type(1) + description
  /// (null-terminated, in the frame's text encoding) + image data (rest).
  EmbeddedArtworkResult _parseApicFrame(Uint8List frame, {required bool isCompactForm}) {
    if (frame.isEmpty) return EmbeddedArtworkResult.none;
    final encoding = frame[0];
    int offset = 1;

    String mimeType;
    if (isCompactForm) {
      if (offset + 3 > frame.length) return EmbeddedArtworkResult.none;
      final code = ascii.decode(frame.sublist(offset, offset + 3), allowInvalid: true).toUpperCase();
      mimeType = code == 'PNG' ? 'image/png' : 'image/jpeg';
      offset += 3;
    } else {
      final mimeEnd = frame.indexOf(0, offset);
      if (mimeEnd == -1) return EmbeddedArtworkResult.none;
      mimeType = ascii.decode(frame.sublist(offset, mimeEnd), allowInvalid: true);
      offset = mimeEnd + 1;
    }

    offset += 1; // picture type byte

    // Skip the null-terminated description, whose terminator width
    // depends on the text encoding (2 zero bytes for UTF-16, 1 for the
    // single-byte encodings).
    final isWide = encoding == 0x01 || encoding == 0x02;
    int descEnd = offset;
    if (isWide) {
      while (descEnd + 1 < frame.length && !(frame[descEnd] == 0 && frame[descEnd + 1] == 0)) {
        descEnd += 2;
      }
      offset = descEnd + 2;
    } else {
      while (descEnd < frame.length && frame[descEnd] != 0) {
        descEnd++;
      }
      offset = descEnd + 1;
    }

    if (offset >= frame.length) return EmbeddedArtworkResult.none;
    return EmbeddedArtworkResult(bytes: frame.sublist(offset), mimeType: mimeType);
  }

  // ---------------------------------------------------------------------
  // MP4/M4A — the 'covr' atom under moov/udta/meta/ilst.
  // ---------------------------------------------------------------------
  Future<EmbeddedArtworkResult> _extractFromMp4(File file) async {
    final raf = await file.open();
    try {
      final length = await file.length();
      final moov = await _findMp4Box(raf, 'moov', 0, length);
      if (moov == null) return EmbeddedArtworkResult.none;

      final udta = await _findMp4Box(raf, 'udta', moov.$1, moov.$1 + moov.$2);
      if (udta == null) return EmbeddedArtworkResult.none;

      final meta = await _findMp4Box(raf, 'meta', udta.$1, udta.$1 + udta.$2);
      if (meta == null) return EmbeddedArtworkResult.none;

      final ilst = await _findMp4Box(raf, 'ilst', meta.$1 + 4, meta.$1 + meta.$2);
      if (ilst == null) return EmbeddedArtworkResult.none;

      final covr = await _findMp4Box(raf, 'covr', ilst.$1, ilst.$1 + ilst.$2);
      if (covr == null) return EmbeddedArtworkResult.none;

      final data = await _findMp4Box(raf, 'data', covr.$1, covr.$1 + covr.$2);
      if (data == null) return EmbeddedArtworkResult.none;

      // 'data' atom: 4-byte type flags (1 = PNG, 13 = JPEG, per the
      // iTunes metadata spec) + 4-byte locale, then raw image bytes.
      final flagsBytes = await _readBytes(raf, data.$1, 4);
      final typeFlag = flagsBytes.length == 4
          ? ByteData.sublistView(flagsBytes).getUint32(0, Endian.big)
          : 13;
      final imageBytes = await _readBytes(raf, data.$1 + 8, data.$2 - 8);

      return EmbeddedArtworkResult(
        bytes: imageBytes,
        mimeType: typeFlag == 1 ? 'image/png' : 'image/jpeg',
      );
    } catch (_) {
      return EmbeddedArtworkResult.none;
    } finally {
      await raf.close();
    }
  }

  Future<(int, int)?> _findMp4Box(RandomAccessFile raf, String fourCC, int start, int end) async {
    int offset = start;
    while (offset + 8 <= end) {
      final header = await _readBytes(raf, offset, 8);
      if (header.length < 8) return null;
      var boxSize = ByteData.sublistView(header, 0, 4).getUint32(0, Endian.big);
      final type = ascii.decode(header.sublist(4, 8), allowInvalid: true);
      int contentStart = offset + 8;

      if (boxSize == 1) {
        final largeSizeBytes = await _readBytes(raf, offset + 8, 8);
        boxSize = ByteData.sublistView(largeSizeBytes).getUint64(0, Endian.big);
        contentStart = offset + 16;
      }
      if (boxSize < 8) break;

      if (type == fourCC) return (contentStart, offset + boxSize - contentStart);
      offset += boxSize;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // FLAC — a METADATA_BLOCK_PICTURE block (type 6).
  // ---------------------------------------------------------------------
  Future<EmbeddedArtworkResult> _extractFromFlac(File file) async {
    final raf = await file.open();
    try {
      final marker = await _readBytes(raf, 0, 4);
      if (marker.length < 4 || ascii.decode(marker) != 'fLaC') return EmbeddedArtworkResult.none;

      int offset = 4;
      while (true) {
        final blockHeader = await _readBytes(raf, offset, 4);
        if (blockHeader.length < 4) break;
        final isLast = (blockHeader[0] & 0x80) != 0;
        final blockType = blockHeader[0] & 0x7F;
        final blockLength = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];
        offset += 4;

        if (blockType == 6) {
          final block = await _readBytes(raf, offset, blockLength);
          return _parseFlacPictureBlock(block);
        }

        offset += blockLength;
        if (isLast) break;
      }
      return EmbeddedArtworkResult.none;
    } finally {
      await raf.close();
    }
  }

  /// METADATA_BLOCK_PICTURE layout (all big-endian):
  /// pictureType(4) + mimeLen(4) + mime + descLen(4) + desc + width(4) +
  /// height(4) + depth(4) + colors(4) + dataLen(4) + data.
  EmbeddedArtworkResult _parseFlacPictureBlock(Uint8List block) {
    try {
      int offset = 4; // skip picture type
      final mimeLen = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.big);
      offset += 4;
      final mimeType = ascii.decode(block.sublist(offset, offset + mimeLen), allowInvalid: true);
      offset += mimeLen;

      final descLen = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.big);
      offset += 4 + descLen;

      offset += 16; // width, height, depth, colors — not needed here
      final dataLen = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.big);
      offset += 4;

      return EmbeddedArtworkResult(bytes: block.sublist(offset, offset + dataLen), mimeType: mimeType);
    } catch (_) {
      return EmbeddedArtworkResult.none;
    }
  }

  // ---------------------------------------------------------------------
  Future<Uint8List> _readBytes(RandomAccessFile raf, int position, int count) async {
    if (count <= 0) return Uint8List(0);
    await raf.setPosition(position);
    return raf.read(count);
  }

  int _synchsafeToInt(List<int> bytes) {
    var value = 0;
    for (final b in bytes) {
      value = (value << 7) | (b & 0x7F);
    }
    return value;
  }

  Uint8List _removeUnsynchronization(Uint8List body) {
    final out = BytesBuilder();
    for (int i = 0; i < body.length; i++) {
      out.addByte(body[i]);
      if (body[i] == 0xFF && i + 1 < body.length && body[i + 1] == 0x00) i++;
    }
    return out.toBytes();
  }
}
