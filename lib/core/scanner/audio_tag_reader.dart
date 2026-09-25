import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Result of reading a single audio file's metadata. All fields are
/// nullable/defaulted rather than throwing — a file with corrupt or absent
/// tags still gets indexed, just with filename-derived fallbacks applied
/// by the caller.
class AudioTagResult {
  String? title;
  String? artist;
  String? album;
  String? genre;
  int? trackNumber;
  int? year;
  int? durationMs;
  int? bitrateKbps;

  AudioTagResult({
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.trackNumber,
    this.year,
    this.durationMs,
    this.bitrateKbps,
  });
}

/// Reads embedded metadata directly from raw file bytes. Each format has
/// its own binary layout, so this class dispatches by extension rather
/// than attempting one universal parser.
class AudioTagReader {
  const AudioTagReader();

  Future<AudioTagResult> read(File file, String extension) async {
    switch (extension) {
      case 'mp3':
        return _readMp3(file);
      case 'flac':
        return _readFlac(file);
      case 'wav':
        return _readWav(file);
      case 'm4a':
      case 'aac':
        return _readMp4Container(file);
      case 'ogg':
        return _readOgg(file);
      default:
        return AudioTagResult();
    }
  }

  // ---------------------------------------------------------------------
  // MP3: ID3v2 header (preferred) with ID3v1 trailer fallback, plus a
  // bitrate/duration estimate from the first valid MPEG frame header.
  // ---------------------------------------------------------------------
  Future<AudioTagResult> _readMp3(File file) async {
    final result = AudioTagResult();
    final length = await file.length();
    final raf = await file.open();
    try {
      final headerBytes = await _readBytes(raf, 0, length < 10 ? length : 10);
      int audioStartOffset = 0;

      if (headerBytes.length >= 10 &&
          headerBytes[0] == 0x49 && // 'I'
          headerBytes[1] == 0x44 && // 'D'
          headerBytes[2] == 0x33) {
        // 'ID3'
        final majorVersion = headerBytes[3];
        final flags = headerBytes[5];
        final tagSize = _synchsafeToInt(headerBytes.sublist(6, 10));
        final unsynchronized = (flags & 0x80) != 0;
        final hasExtendedHeader = (flags & 0x40) != 0;

        int bodyStart = 10;
        int bodyLength = tagSize;

        final fullTagBytes = await _readBytes(raf, 0, 10 + tagSize);
        Uint8List body = fullTagBytes.sublist(10, 10 + tagSize.clamp(0, fullTagBytes.length - 10));

        if (hasExtendedHeader && body.length >= 4) {
          final extSize = majorVersion >= 4
              ? _synchsafeToInt(body.sublist(0, 4))
              : ByteData.sublistView(body, 0, 4).getUint32(0, Endian.big);
          if (extSize < body.length) {
            body = body.sublist(extSize);
          }
        }

        if (unsynchronized) {
          body = _removeUnsynchronization(body);
        }

        _parseId3v2Frames(body, majorVersion, result);
        audioStartOffset = bodyStart + bodyLength;
      }

      // ID3v1 fallback (only fills fields ID3v2 left empty) — fixed 128
      // byte trailer: "TAG" + title(30) + artist(30) + album(30) +
      // year(4) + comment(30) + genre(1).
      if (length >= 128 && (result.title == null || result.artist == null)) {
        final tail = await _readBytes(raf, length - 128, 128);
        if (tail[0] == 0x54 && tail[1] == 0x41 && tail[2] == 0x47) {
          result.title ??= _trimNullPadded(tail.sublist(3, 33));
          result.artist ??= _trimNullPadded(tail.sublist(33, 63));
          result.album ??= _trimNullPadded(tail.sublist(63, 93));
          final yearStr = _trimNullPadded(tail.sublist(93, 97));
          result.year ??= int.tryParse(yearStr);
        }
      }

      final frameInfo = await _estimateMp3DurationAndBitrate(raf, audioStartOffset, length);
      result.durationMs = frameInfo.$1;
      result.bitrateKbps = frameInfo.$2;
    } finally {
      await raf.close();
    }
    return result;
  }

  void _parseId3v2Frames(Uint8List body, int majorVersion, AudioTagResult result) {
    int offset = 0;
    final idLength = majorVersion == 2 ? 3 : 4;
    final sizeIsSynchsafe = majorVersion >= 4;

    while (offset + idLength + (majorVersion == 2 ? 3 : 4) < body.length) {
      final idBytes = body.sublist(offset, offset + idLength);
      if (idBytes.every((b) => b == 0)) break; // padding reached

      final frameId = ascii.decode(idBytes, allowInvalid: true);
      offset += idLength;

      int frameSize;
      if (majorVersion == 2) {
        frameSize = (body[offset] << 16) | (body[offset + 1] << 8) | body[offset + 2];
        offset += 3;
      } else {
        final sizeBytes = body.sublist(offset, offset + 4);
        frameSize = sizeIsSynchsafe
            ? _synchsafeToInt(sizeBytes)
            : ByteData.sublistView(sizeBytes).getUint32(0, Endian.big);
        offset += 4;
        offset += 2; // flags (v2.3/2.4 only)
      }

      if (frameSize <= 0 || offset + frameSize > body.length) break;
      final frameBody = body.sublist(offset, offset + frameSize);
      offset += frameSize;

      _applyFrame(frameId, frameBody, result);
    }
  }

  void _applyFrame(String frameId, Uint8List frameBody, AudioTagResult result) {
    switch (frameId) {
      case 'TIT2':
      case 'TT2':
        result.title = _decodeTextFrame(frameBody);
        break;
      case 'TPE1':
      case 'TP1':
        result.artist = _decodeTextFrame(frameBody);
        break;
      case 'TALB':
      case 'TAL':
        result.album = _decodeTextFrame(frameBody);
        break;
      case 'TCON':
      case 'TCO':
        result.genre = _decodeTextFrame(frameBody);
        break;
      case 'TRCK':
      case 'TRK':
        final raw = _decodeTextFrame(frameBody) ?? '';
        result.trackNumber = int.tryParse(raw.split('/').first.trim());
        break;
      case 'TYER':
      case 'TYE':
        result.year = int.tryParse(_decodeTextFrame(frameBody) ?? '');
        break;
      case 'TDRC':
        final raw = _decodeTextFrame(frameBody) ?? '';
        result.year = int.tryParse(raw.length >= 4 ? raw.substring(0, 4) : raw);
        break;
    }
  }

  /// ID3 text frames are prefixed with a one-byte encoding marker:
  /// 0x00 = ISO-8859-1, 0x01 = UTF-16 with BOM, 0x02 = UTF-16BE, 0x03 = UTF-8.
  String? _decodeTextFrame(Uint8List frameBody) {
    if (frameBody.isEmpty) return null;
    final encoding = frameBody[0];
    final data = frameBody.sublist(1);
    try {
      switch (encoding) {
        case 0x00:
          return latin1.decode(data, allowInvalid: true).replaceAll('\x00', '').trim();
        case 0x01:
          return _decodeUtf16(data, bomPresent: true);
        case 0x02:
          return _decodeUtf16(data, bomPresent: false);
        case 0x03:
          return utf8.decode(data, allowMalformed: true).replaceAll('\x00', '').trim();
        default:
          return latin1.decode(data, allowInvalid: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {
      return null;
    }
  }

  String _decodeUtf16(Uint8List data, {required bool bomPresent}) {
    var bytes = data;
    var endian = Endian.little;
    if (bomPresent && bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        endian = Endian.little;
        bytes = bytes.sublist(2);
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        endian = Endian.big;
        bytes = bytes.sublist(2);
      }
    }
    final units = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final unit = endian == Endian.little
          ? (bytes[i + 1] << 8) | bytes[i]
          : (bytes[i] << 8) | bytes[i + 1];
      if (unit == 0) break;
      units.add(unit);
    }
    return String.fromCharCodes(units).trim();
  }

  Uint8List _removeUnsynchronization(Uint8List body) {
    final out = BytesBuilder();
    for (int i = 0; i < body.length; i++) {
      out.addByte(body[i]);
      if (body[i] == 0xFF && i + 1 < body.length && body[i + 1] == 0x00) {
        i++; // drop the stuffed zero byte following any 0xFF
      }
    }
    return out.toBytes();
  }

  int _synchsafeToInt(List<int> bytes) {
    var value = 0;
    for (final b in bytes) {
      value = (value << 7) | (b & 0x7F);
    }
    return value;
  }

  String _trimNullPadded(Uint8List bytes) {
    return latin1.decode(bytes, allowInvalid: true).replaceAll('\x00', '').trim();
  }

  /// Locates the first valid MPEG audio frame header after any ID3v2 tag,
  /// reads its bitrate, and estimates total duration as
  /// (fileSize - audioStart) * 8 / bitrate. This is exact for constant
  /// bitrate files and a reasonable approximation for VBR files without a
  /// Xing/VBRI header; a fully sample-accurate VBR duration would require
  /// decoding every frame, which the scanner defers to first playback.
  Future<(int?, int?)> _estimateMp3DurationAndBitrate(
    RandomAccessFile raf,
    int searchStart,
    int fileLength,
  ) async {
    const bitrateTableV1L3 = [
      0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
    ];
    const sampleRateTableV1 = [44100, 48000, 32000, 0];

    final searchWindow = await _readBytes(
      raf,
      searchStart,
      (fileLength - searchStart).clamp(0, 65536),
    );

    for (int i = 0; i + 4 < searchWindow.length; i++) {
      if (searchWindow[i] != 0xFF) continue;
      final b2 = searchWindow[i + 1];
      if ((b2 & 0xE0) != 0xE0) continue; // not a frame sync

      final versionBits = (b2 >> 3) & 0x03;
      final layerBits = (b2 >> 1) & 0x03;
      if (versionBits != 0x03 || layerBits != 0x01) continue; // require MPEG1 Layer III

      final b3 = searchWindow[i + 2];
      final bitrateIndex = (b3 >> 4) & 0x0F;
      final sampleRateIndex = (b3 >> 2) & 0x03;
      if (bitrateIndex == 0 || bitrateIndex == 15 || sampleRateIndex == 3) continue;

      final bitrateKbps = bitrateTableV1L3[bitrateIndex];
      final sampleRate = sampleRateTableV1[sampleRateIndex];
      if (bitrateKbps == 0 || sampleRate == 0) continue;

      final audioBytes = fileLength - (searchStart + i);
      final durationSeconds = (audioBytes * 8) / (bitrateKbps * 1000);
      return ((durationSeconds * 1000).round(), bitrateKbps);
    }
    return (null, null);
  }

  // ---------------------------------------------------------------------
  // FLAC: STREAMINFO metadata block gives exact sample count + rate, so
  // duration here is sample-accurate rather than estimated.
  // ---------------------------------------------------------------------
  Future<AudioTagResult> _readFlac(File file) async {
    final result = AudioTagResult();
    final raf = await file.open();
    try {
      final marker = await _readBytes(raf, 0, 4);
      if (marker.length < 4 || latin1.decode(marker) != 'fLaC') return result;

      int offset = 4;
      while (true) {
        final blockHeader = await _readBytes(raf, offset, 4);
        if (blockHeader.length < 4) break;
        final isLast = (blockHeader[0] & 0x80) != 0;
        final blockType = blockHeader[0] & 0x7F;
        final blockLength =
            (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];
        offset += 4;

        if (blockType == 0) {
          // STREAMINFO
          final block = await _readBytes(raf, offset, blockLength);
          if (block.length >= 18) {
            final sampleRate = (block[10] << 12) | (block[11] << 4) | (block[12] >> 4);
            final totalSamples = ((block[13] & 0x0F) << 32) |
                (block[14] << 24) |
                (block[15] << 16) |
                (block[16] << 8) |
                block[17];
            if (sampleRate > 0) {
              result.durationMs = ((totalSamples / sampleRate) * 1000).round();
            }
          }
        } else if (blockType == 4) {
          // VORBIS_COMMENT — reuse the Ogg comment parser on this block.
          final block = await _readBytes(raf, offset, blockLength);
          _parseVorbisComment(block, result);
        }

        offset += blockLength;
        if (isLast) break;
      }
    } finally {
      await raf.close();
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // WAV: PCM fmt chunk gives byte rate directly, so duration is exact
  // from the data chunk size — no tag support (RIFF INFO tags are rare
  // in practice for music files and are skipped).
  // ---------------------------------------------------------------------
  Future<AudioTagResult> _readWav(File file) async {
    final result = AudioTagResult();
    final raf = await file.open();
    try {
      final header = await _readBytes(raf, 0, 12);
      if (header.length < 12 || latin1.decode(header.sublist(0, 4)) != 'RIFF') {
        return result;
      }

      int offset = 12;
      int byteRate = 0;
      final length = await file.length();

      while (offset + 8 <= length) {
        final chunkHeader = await _readBytes(raf, offset, 8);
        if (chunkHeader.length < 8) break;
        final chunkId = latin1.decode(chunkHeader.sublist(0, 4));
        final chunkSize = ByteData.sublistView(chunkHeader, 4, 8).getUint32(0, Endian.little);
        offset += 8;

        if (chunkId == 'fmt ') {
          final fmt = await _readBytes(raf, offset, chunkSize);
          if (fmt.length >= 16) {
            byteRate = ByteData.sublistView(fmt, 8, 12).getUint32(0, Endian.little);
            final bitsPerSample = ByteData.sublistView(fmt, 14, 16).getUint16(0, Endian.little);
            final numChannels = ByteData.sublistView(fmt, 2, 4).getUint16(0, Endian.little);
            result.bitrateKbps = ((byteRate * 8) / 1000).round();
            // silence unused-var lint if bitsPerSample/numChannels aren't
            // needed beyond byteRate for duration math
            if (bitsPerSample < 0 || numChannels < 0) {}
          }
        } else if (chunkId == 'data' && byteRate > 0) {
          result.durationMs = ((chunkSize / byteRate) * 1000).round();
          break;
        }

        offset += chunkSize + (chunkSize.isOdd ? 1 : 0); // chunks are word-aligned
      }
    } finally {
      await raf.close();
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // OGG (Vorbis): parses the identification + comment header packets from
  // the first two Ogg pages for tags, and estimates duration from the
  // granule position of the last page.
  // ---------------------------------------------------------------------
  Future<AudioTagResult> _readOgg(File file) async {
    final result = AudioTagResult();
    final raf = await file.open();
    try {
      final length = await file.length();

      // Identification header page (first page) for sample rate.
      final firstPage = await _readBytes(raf, 0, 4096.clamp(0, length));
      int sampleRate = 44100;
      final idPacketOffset = _findBytes(firstPage, ascii.encode('vorbis'));
      if (idPacketOffset != -1 && idPacketOffset + 16 <= firstPage.length) {
        sampleRate = ByteData.sublistView(firstPage, idPacketOffset + 6, idPacketOffset + 10)
            .getUint32(0, Endian.little);
      }

      final commentPacketOffset = _findBytes(firstPage, ascii.encode('vorbis'), idPacketOffset + 1);
      if (commentPacketOffset != -1) {
        _parseVorbisComment(firstPage.sublist(commentPacketOffset - 1), result, skipVendorAt: 6);
      }

      // Last page's granule position (offset 6..14 of the page header)
      // gives total PCM sample count for duration.
      final tailWindow = await _readBytes(raf, (length - 8192).clamp(0, length), 8192.clamp(0, length));
      final lastOggS = _lastIndexOfBytes(tailWindow, ascii.encode('OggS'));
      if (lastOggS != -1 && lastOggS + 14 <= tailWindow.length && sampleRate > 0) {
        final granule = ByteData.sublistView(tailWindow, lastOggS + 6, lastOggS + 14)
            .getUint64(0, Endian.little);
        result.durationMs = ((granule / sampleRate) * 1000).round();
      }
    } catch (_) {
      // Ogg parsing is best-effort; failures fall back to filename-derived
      // metadata and lazy duration resolution at first playback.
    } finally {
      await raf.close();
    }
    return result;
  }

  void _parseVorbisComment(Uint8List block, AudioTagResult result, {int skipVendorAt = 0}) {
    try {
      int offset = skipVendorAt;
      if (offset + 4 > block.length) return;
      final vendorLength = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.little);
      offset += 4 + vendorLength;
      if (offset + 4 > block.length) return;
      final commentCount = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.little);
      offset += 4;

      for (int i = 0; i < commentCount && offset + 4 <= block.length; i++) {
        final len = ByteData.sublistView(block, offset, offset + 4).getUint32(0, Endian.little);
        offset += 4;
        if (offset + len > block.length) break;
        final comment = utf8.decode(block.sublist(offset, offset + len), allowMalformed: true);
        offset += len;

        final eq = comment.indexOf('=');
        if (eq == -1) continue;
        final key = comment.substring(0, eq).toUpperCase();
        final value = comment.substring(eq + 1);

        switch (key) {
          case 'TITLE':
            result.title = value;
            break;
          case 'ARTIST':
            result.artist = value;
            break;
          case 'ALBUM':
            result.album = value;
            break;
          case 'GENRE':
            result.genre = value;
            break;
          case 'DATE':
            result.year = int.tryParse(value.length >= 4 ? value.substring(0, 4) : value);
            break;
          case 'TRACKNUMBER':
            result.trackNumber = int.tryParse(value.split('/').first);
            break;
        }
      }
    } catch (_) {
      // Best-effort — a malformed comment block leaves whatever fields
      // were already parsed intact.
    }
  }

  // ---------------------------------------------------------------------
  // M4A/AAC (MP4 container): walks the box tree to moov/udta/meta/ilst for
  // tags and moov/trak/mdia/mdhd for duration + timescale.
  // ---------------------------------------------------------------------
  Future<AudioTagResult> _readMp4Container(File file) async {
    final result = AudioTagResult();
    final raf = await file.open();
    try {
      final length = await file.length();
      final moovBox = await _findMp4Box(raf, 'moov', 0, length);
      if (moovBox == null) return result;

      final mvhd = await _findMp4Box(raf, 'mvhd', moovBox.$1, moovBox.$1 + moovBox.$2);
      if (mvhd != null) {
        final header = await _readBytes(raf, mvhd.$1, mvhd.$2);
        if (header.length >= 20) {
          final version = header[0];
          if (version == 1 && header.length >= 32) {
            final timescale = ByteData.sublistView(header, 20, 24).getUint32(0, Endian.big);
            final duration = ByteData.sublistView(header, 24, 32).getUint64(0, Endian.big);
            if (timescale > 0) {
              result.durationMs = ((duration / timescale) * 1000).round();
            }
          } else if (header.length >= 20) {
            final timescale = ByteData.sublistView(header, 12, 16).getUint32(0, Endian.big);
            final duration = ByteData.sublistView(header, 16, 20).getUint32(0, Endian.big);
            if (timescale > 0) {
              result.durationMs = ((duration / timescale) * 1000).round();
            }
          }
        }
      }

      final udta = await _findMp4Box(raf, 'udta', moovBox.$1, moovBox.$1 + moovBox.$2);
      if (udta != null) {
        final meta = await _findMp4Box(raf, 'meta', udta.$1, udta.$1 + udta.$2);
        if (meta != null) {
          // 'meta' box has a 4-byte version/flags field before its children.
          final ilst = await _findMp4Box(raf, 'ilst', meta.$1 + 4, meta.$1 + meta.$2);
          if (ilst != null) {
            await _parseIlstAtoms(raf, ilst.$1, ilst.$1 + ilst.$2, result);
          }
        }
      }
    } catch (_) {
      // Best-effort container walk — partial/streamed M4A files fall back
      // to filename-derived metadata.
    } finally {
      await raf.close();
    }
    return result;
  }

  /// Searches [start, end) for a top-level box with the given fourCC and
  /// returns (contentStart, contentLength), or null if absent.
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

      if (type == fourCC) {
        return (contentStart, offset + boxSize - contentStart);
      }
      offset += boxSize;
    }
    return null;
  }

  Future<void> _parseIlstAtoms(RandomAccessFile raf, int start, int end, AudioTagResult result) async {
    const atomMap = {
      '©nam': 'title',
      '©ART': 'artist',
      '©alb': 'album',
      '©gen': 'genre',
      '©day': 'year',
      'trkn': 'track',
    };

    int offset = start;
    while (offset + 8 <= end) {
      final header = await _readBytes(raf, offset, 8);
      if (header.length < 8) break;
      final boxSize = ByteData.sublistView(header, 0, 4).getUint32(0, Endian.big);
      final type = utf8.decode(header.sublist(4, 8), allowMalformed: true);
      if (boxSize < 8 || offset + boxSize > end) break;

      final field = atomMap[type];
      if (field != null) {
        final dataBox = await _findMp4Box(raf, 'data', offset + 8, offset + boxSize);
        if (dataBox != null) {
          final data = await _readBytes(raf, dataBox.$1 + 8, dataBox.$2 - 8); // skip version/flags/locale
          _applyMp4Field(field, data, result);
        }
      }
      offset += boxSize;
    }
  }

  void _applyMp4Field(String field, Uint8List data, AudioTagResult result) {
    switch (field) {
      case 'title':
        result.title = utf8.decode(data, allowMalformed: true).trim();
        break;
      case 'artist':
        result.artist = utf8.decode(data, allowMalformed: true).trim();
        break;
      case 'album':
        result.album = utf8.decode(data, allowMalformed: true).trim();
        break;
      case 'genre':
        result.genre = utf8.decode(data, allowMalformed: true).trim();
        break;
      case 'year':
        final text = utf8.decode(data, allowMalformed: true).trim();
        result.year = int.tryParse(text.length >= 4 ? text.substring(0, 4) : text);
        break;
      case 'track':
        if (data.length >= 4) {
          result.trackNumber = ByteData.sublistView(data, 2, 4).getUint16(0, Endian.big);
        }
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Shared byte helpers
  // ---------------------------------------------------------------------
  Future<Uint8List> _readBytes(RandomAccessFile raf, int position, int count) async {
    if (count <= 0) return Uint8List(0);
    await raf.setPosition(position);
    return raf.read(count);
  }

  int _findBytes(Uint8List haystack, List<int> needle, [int from = 0]) {
    if (from < 0) from = 0;
    outer:
    for (int i = from; i <= haystack.length - needle.length; i++) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  int _lastIndexOfBytes(Uint8List haystack, List<int> needle) {
    outer:
    for (int i = haystack.length - needle.length; i >= 0; i--) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
