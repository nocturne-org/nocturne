import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/chapter.dart';
import 'audio_metadata.dart';

/// Robuster Parser fuer ID3v1, ID3v2.3 und ID3v2.4 Metadaten-Tags.
class Id3Parser {
  const Id3Parser();

  /// Synchsafe-Integer Konvertierung (7 Bits pro Byte).
  static int decodeSynchsafe(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  /// Big-Endian 32-Bit Integer Konvertierung.
  static int decodeUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  /// Dekodiert Text-Strings abhaengig vom fuehrenden Encoding-Byte.
  static String decodeText(Uint8List bytes, int offset, int length) {
    if (length <= 0 || offset + length > bytes.length) return '';
    final encoding = bytes[offset];
    final data = bytes.sublist(offset + 1, offset + length);

    try {
      switch (encoding) {
        case 0:
          // ISO-8859-1 (Latin-1)
          return latin1.decode(data).replaceAll('\x00', '').trim();
        case 1:
          // UTF-16 mit BOM
          return _decodeUtf16(data).replaceAll('\x00', '').trim();
        case 2:
          // UTF-16BE ohne BOM
          return _decodeUtf16(data, defaultBigEndian: true)
              .replaceAll('\x00', '')
              .trim();
        case 3:
        default:
          // UTF-8
          return utf8
              .decode(data, allowMalformed: true)
              .replaceAll('\x00', '')
              .trim();
      }
    } catch (_) {
      return latin1
          .decode(data, allowInvalid: true)
          .replaceAll('\x00', '')
          .trim();
    }
  }

  static String _decodeUtf16(Uint8List bytes, {bool defaultBigEndian = false}) {
    if (bytes.length < 2) return '';
    var isBigEndian = defaultBigEndian;
    var start = 0;

    // BOM-Pruefung
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      isBigEndian = true;
      start = 2;
    } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      isBigEndian = false;
      start = 2;
    }

    final codeUnits = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      final codeUnit = isBigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit != 0) {
        codeUnits.add(codeUnit);
      }
    }
    return String.fromCharCodes(codeUnits);
  }

  /// Parst ID3-Tags aus Byte-Puffern.
  AudioMetadata? parse(Uint8List bytes, {String fallbackTitle = ''}) {
    // 1. Zuerst ID3v2 am Dateianfang pruefen
    if (bytes.length >= 10 &&
        bytes[0] == 0x49 && // 'I'
        bytes[1] == 0x44 && // 'D'
        bytes[2] == 0x33) {
      // '3'
      final v2Meta = _parseId3v2(bytes, fallbackTitle);
      if (v2Meta != null) return v2Meta;
    }

    // 2. Fallback: ID3v1 am Dateiende pruefen (letzte 128 Bytes)
    if (bytes.length >= 128) {
      final v1Offset = bytes.length - 128;
      if (bytes[v1Offset] == 0x54 && // 'T'
          bytes[v1Offset + 1] == 0x41 && // 'A'
          bytes[v1Offset + 2] == 0x47) {
        // 'G'
        return _parseId3v1(bytes, v1Offset, fallbackTitle);
      }
    }

    return null;
  }

  AudioMetadata? _parseId3v2(Uint8List bytes, String fallbackTitle) {
    final majorVersion = bytes[3]; // z. B. 3 fuer v2.3, 4 fuer v2.4
    final isV24 = majorVersion == 4;
    final tagSize = decodeSynchsafe(bytes, 6);
    final totalHeaderAndTag = 10 + tagSize;
    final maxOffset =
        totalHeaderAndTag > bytes.length ? bytes.length : totalHeaderAndTag;

    String? title;
    String? author;
    String? album;
    int? trackNumber;
    int? year;
    Uint8List? coverBytes;
    String? coverMime;
    final chapters = <Chapter>[];

    var offset = 10;
    var chapterIndex = 0;

    while (offset + 10 <= maxOffset) {
      // Frame-ID aus 4 Zeichen lesen
      final frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));

      // Padding am Ende des ID3-Blocks erkennen
      if (frameId.codeUnitAt(0) == 0) break;

      final frameSize = isV24
          ? decodeSynchsafe(bytes, offset + 4)
          : decodeUint32(bytes, offset + 4);

      if (frameSize <= 0 || offset + 10 + frameSize > bytes.length) break;

      final frameDataStart = offset + 10;

      switch (frameId) {
        case 'TIT2': // Title
          title = decodeText(bytes, frameDataStart, frameSize);
          break;
        case 'TPE1': // Artist / Author
          author = decodeText(bytes, frameDataStart, frameSize);
          break;
        case 'TALB': // Album
          album = decodeText(bytes, frameDataStart, frameSize);
          break;
        case 'TRCK': // Track Number
          final trackStr = decodeText(bytes, frameDataStart, frameSize);
          final parts = trackStr.split('/');
          trackNumber = int.tryParse(parts.first.trim());
          break;
        case 'TYER': // Year (v2.3)
        case 'TDRC': // Recording Time / Year (v2.4)
          final yearStr = decodeText(bytes, frameDataStart, frameSize);
          if (yearStr.length >= 4) {
            year = int.tryParse(yearStr.substring(0, 4));
          }
          break;
        case 'APIC': // Attached Picture (Cover)
          try {
            var p = frameDataStart + 1; // nach Encoding-Byte
            // MIME-Type lesen (Null-terminiert)
            final mimeStart = p;
            while (p < frameDataStart + frameSize && bytes[p] != 0) {
              p++;
            }
            coverMime = latin1.decode(bytes.sublist(mimeStart, p));
            p++; // Null-Byte ueberspringen
            p++; // Picture Type (1 Byte, z. B. 0x03 Front Cover)
            // Description ueberspringen (Null-terminiert)
            while (p < frameDataStart + frameSize && bytes[p] != 0) {
              p++;
            }
            p++; // Null-Byte ueberspringen
            if (p < frameDataStart + frameSize) {
              coverBytes = bytes.sublist(p, frameDataStart + frameSize);
            }
          } catch (_) {}
          break;
        case 'CHAP': // Embedded Chapter
          try {
            var cp = frameDataStart;
            // Element-ID (Null-terminiert)
            final idStart = cp;
            while (cp < frameDataStart + frameSize && bytes[cp] != 0) {
              cp++;
            }
            final elemId = latin1.decode(bytes.sublist(idStart, cp));
            cp++; // Null-Byte
            if (cp + 16 <= frameDataStart + frameSize) {
              final startMs = decodeUint32(bytes, cp);
              final endMs = decodeUint32(bytes, cp + 4);
              cp +=
                  16; // StartTime(4), EndTime(4), StartOffset(4), EndOffset(4)

              var chapterTitle = 'Kapitel ${chapterIndex + 1}';
              // Optionale Sub-Frames parsen (z. B. TIT2)
              if (cp + 10 < frameDataStart + frameSize) {
                final subId = String.fromCharCodes(bytes.sublist(cp, cp + 4));
                final subSize = decodeUint32(bytes, cp + 4);
                if (subId == 'TIT2' &&
                    cp + 10 + subSize <= frameDataStart + frameSize) {
                  final subTitle = decodeText(bytes, cp + 10, subSize);
                  if (subTitle.isNotEmpty) chapterTitle = subTitle;
                }
              }

              chapters.add(
                Chapter(
                  id: elemId.isNotEmpty ? elemId : 'chap-$chapterIndex',
                  title: chapterTitle,
                  start: Duration(milliseconds: startMs),
                  end: Duration(
                      milliseconds: endMs >= startMs ? endMs : startMs),
                  index: chapterIndex++,
                ),
              );
            }
          } catch (_) {}
          break;
      }

      offset += 10 + frameSize;
    }

    return AudioMetadata(
      title: (title != null && title.isNotEmpty) ? title : fallbackTitle,
      author: author,
      album: album,
      trackNumber: trackNumber,
      year: year,
      coverArtBytes: coverBytes,
      coverMimeType: coverMime ?? 'image/jpeg',
      chapters: chapters,
      rawFormat: 'ID3v2.$majorVersion',
    );
  }

  AudioMetadata _parseId3v1(Uint8List bytes, int offset, String fallbackTitle) {
    // ID3v1 Layout: 3 bytes TAG, 30 title, 30 artist, 30 album, 4 year, 28 comment, 1 zero, 1 track, 1 genre
    final title = latin1
        .decode(bytes.sublist(offset + 3, offset + 33))
        .replaceAll('\x00', '')
        .trim();
    final artist = latin1
        .decode(bytes.sublist(offset + 33, offset + 63))
        .replaceAll('\x00', '')
        .trim();
    final album = latin1
        .decode(bytes.sublist(offset + 63, offset + 93))
        .replaceAll('\x00', '')
        .trim();
    final yearStr = latin1
        .decode(bytes.sublist(offset + 93, offset + 97))
        .replaceAll('\x00', '')
        .trim();

    int? track;
    // ID3v1.1 Erkennung: Byte 125 ist 0x00 und Byte 126 ist Track-Nummer
    if (bytes[offset + 125] == 0 && bytes[offset + 126] != 0) {
      track = bytes[offset + 126];
    }

    return AudioMetadata(
      title: title.isNotEmpty ? title : fallbackTitle,
      author: artist.isNotEmpty ? artist : null,
      album: album.isNotEmpty ? album : null,
      trackNumber: track,
      year: int.tryParse(yearStr),
      rawFormat: 'ID3v1',
    );
  }
}
