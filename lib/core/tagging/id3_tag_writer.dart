import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TagEditFields {
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? trackNumber;
  final int? year;

  const TagEditFields(
      {this.title,
      this.artist,
      this.album,
      this.genre,
      this.trackNumber,
      this.year});
}

/// Writes ID3v2.3 tags to MP3 files by rebuilding the tag block entirely
/// and splicing it in front of the original audio data (after stripping
/// whatever ID3v2 tag, if any, was already there). This is the standard
/// approach real tag editors use — ID3v2's variable-length frames make
/// in-place field patching impractical in general, since a new value is
/// essentially never the same byte length as the old one.
///
/// Scope note: this class handles MP3/ID3v2 only. Writing tags back to
/// M4A (rewriting MP4 'ilst' atoms, which requires re-computing box sizes
/// up the whole moov/udta/meta chain) and FLAC (rewriting VORBIS_COMMENT
/// metadata blocks, including block-length renegotiation if the new
/// comment no longer fits in existing padding) are real, structurally
/// different problems from ID3v2 rewriting, not smaller versions of it —
/// they're a follow-up module, not included here.
///
/// **Android scoped-storage caveat:** the plain `File`/`dart:io` write
/// below works unmodified for files under app-owned storage, but on
/// API 30+ a file that was scanned into MediaStore from shared storage
/// (i.e. an ordinary song in the user's Music folder) cannot be opened
/// for direct write this way — the OS requires going through
/// `MediaStore.createWriteRequest()` (a system permission dialog) and
/// writing via the returned `Uri`'s file descriptor instead of a raw
/// path. That MediaStore write-request bridge is real native-side work
/// (a Kotlin plugin analogous to DemuxPlugin.kt) not yet built here —
/// calling this class today will work for app-internal files and fail
/// with a permission error for arbitrary library files on API 30+ until
/// that bridge is added.
class Id3TagWriter {
  const Id3TagWriter();

  Future<void> writeTags(String filePath, TagEditFields fields) async {
    final file = File(filePath);
    final originalBytes = await file.readAsBytes();

    final existingTagSize = _existingId3v2Size(originalBytes);
    final audioData = originalBytes.sublist(existingTagSize);

    final newTag = _buildId3v2Tag(fields);

    final output = BytesBuilder();
    output.add(newTag);
    output.add(audioData);

    // Write to a temp file first and rename over the original — if the
    // process is killed mid-write, the original file is left intact
    // rather than truncated/corrupted.
    final tempFile = File('$filePath.tmp');
    await tempFile.writeAsBytes(output.toBytes(), flush: true);
    await tempFile.rename(filePath);
  }

  int _existingId3v2Size(Uint8List bytes) {
    if (bytes.length < 10 ||
        bytes[0] != 0x49 ||
        bytes[1] != 0x44 ||
        bytes[2] != 0x33) {
      return 0; // no existing ID3v2 tag
    }
    final tagSize = _synchsafeToInt(bytes.sublist(6, 10));
    return 10 + tagSize;
  }

  Uint8List _buildId3v2Tag(TagEditFields fields) {
    final frames = BytesBuilder();

    void addTextFrame(String frameId, String? value) {
      if (value == null || value.isEmpty) return;
      final encoded = utf8.encode(value);
      // Encoding byte 0x03 = UTF-8 (ID3v2.4 adds this; ID3v2.3 technically
      // predates UTF-8 support, but every real-world player — including
      // every version of Android/iOS/desktop players in current use —
      // reads it correctly, and it avoids the Latin-1/UTF-16 encoding
      // pitfalls for any non-ASCII title/artist text.
      final frameBody = BytesBuilder()
        ..addByte(0x03)
        ..add(encoded);
      final bodyBytes = frameBody.toBytes();

      frames.add(ascii.encode(frameId));
      frames.add(_uint32BigEndian(bodyBytes
          .length)); // ID3v2.3 frame size is a plain (non-synchsafe) uint32
      frames.add([0x00, 0x00]); // frame flags
      frames.add(bodyBytes);
    }

    addTextFrame('TIT2', fields.title);
    addTextFrame('TPE1', fields.artist);
    addTextFrame('TALB', fields.album);
    addTextFrame('TCON', fields.genre);
    if (fields.trackNumber != null)
      addTextFrame('TRCK', fields.trackNumber.toString());
    if (fields.year != null) addTextFrame('TYER', fields.year.toString());

    final frameBytes = frames.toBytes();

    final header = BytesBuilder()
      ..add(ascii.encode('ID3'))
      ..addByte(3) // major version
      ..addByte(0) // revision
      ..addByte(0x00) // flags — no unsynchronization, no extended header
      ..add(_synchsafeInt(frameBytes.length));

    final tag = BytesBuilder()
      ..add(header.toBytes())
      ..add(frameBytes);

    return tag.toBytes();
  }

  Uint8List _uint32BigEndian(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  List<int> _synchsafeInt(int value) {
    return [
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F,
    ];
  }

  int _synchsafeToInt(List<int> bytes) {
    var value = 0;
    for (final b in bytes) {
      value = (value << 7) | (b & 0x7F);
    }
    return value;
  }
}
