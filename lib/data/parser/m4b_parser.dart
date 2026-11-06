import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/chapter.dart';
import 'audio_metadata.dart';

/// Parser fuer QuickTime / MP4 ISO-Base-Media-Atome in M4B- und M4A-Dateien.
/// Extrahiert Metadaten (Titel, Autor, Album, Track, Cover) und 'chpl' Kapitel-Atome.
class M4bParser {
  const M4bParser();

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _readUint64(Uint8List bytes, int offset) {
    final high = _readUint32(bytes, offset);
    final low = _readUint32(bytes, offset + 4);
    return (high * 4294967296) + low;
  }

  static String _readFourCC(Uint8List bytes, int offset) {
    return latin1.decode(bytes.sublist(offset, offset + 4));
  }

  /// Parst M4B Metadaten und Kapitel aus einem Byte-Puffer.
  AudioMetadata? parse(Uint8List bytes, {String fallbackTitle = ''}) {
    if (bytes.length < 8) return null;

    String? title;
    String? author;
    String? album;
    int? trackNumber;
    int? year;
    Uint8List? coverBytes;
    String? coverMime;
    final chapters = <Chapter>[];

    // Rekursive oder sequentielle Atom-Suche
    _scanAtoms(bytes, 0, bytes.length, (type, offset, size, dataStart, dataSize) {
      if (type == 'chpl') {
        _parseChplAtom(bytes, dataStart, dataSize, chapters);
      } else if (type == '©nam' || type == 'titl') {
        final val = _extractStringFromDataAtom(bytes, dataStart, dataSize);
        if (val != null && val.isNotEmpty) title = val;
      } else if (type == '©ART' || type == 'aART' || type == 'perf') {
        final val = _extractStringFromDataAtom(bytes, dataStart, dataSize);
        if (val != null && val.isNotEmpty) author = val;
      } else if (type == '©alb' || type == 'albm') {
        final val = _extractStringFromDataAtom(bytes, dataStart, dataSize);
        if (val != null && val.isNotEmpty) album = val;
      } else if (type == '©day' || type == 'yrrc') {
        final val = _extractStringFromDataAtom(bytes, dataStart, dataSize);
        if (val != null && val.length >= 4) {
          year = int.tryParse(val.substring(0, 4));
        }
      } else if (type == 'trkn') {
        trackNumber = _extractTrackNumber(bytes, dataStart, dataSize);
      } else if (type == 'covr') {
        final coverData = _extractCover(bytes, dataStart, dataSize);
        if (coverData != null) {
          coverBytes = coverData.$1;
          coverMime = coverData.$2;
        }
      }
    });

    if (title == null && author == null && chapters.isEmpty && coverBytes == null) {
      // Keine M4B Atome erkannt
      return null;
    }

    final effectiveTitle = title;
    return AudioMetadata(
      title: (effectiveTitle != null && effectiveTitle.isNotEmpty) ? effectiveTitle : fallbackTitle,
      author: author,
      album: album,
      trackNumber: trackNumber,
      year: year,
      coverArtBytes: coverBytes,
      coverMimeType: coverMime ?? 'image/jpeg',
      chapters: chapters,
      rawFormat: 'M4B/QuickTime',
    );
  }

  void _scanAtoms(
    Uint8List bytes,
    int startOffset,
    int endOffset,
    void Function(String type, int offset, int size, int dataStart, int dataSize) onAtom,
  ) {
    var offset = startOffset;
    final containerTypes = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'udta', 'meta', 'ilst'};

    while (offset + 8 <= endOffset) {
      final size = _readUint32(bytes, offset);
      if (size < 8) break; // Ungueltige Atom-Groesse oder EOF
      final type = _readFourCC(bytes, offset + 4);

      final atomEnd = offset + size <= endOffset ? offset + size : endOffset;
      final dataStart = offset + 8;
      final dataSize = atomEnd - dataStart;

      onAtom(type, offset, size, dataStart, dataSize);

      if (containerTypes.contains(type)) {
        // 'meta' Atom enthaelt haeufig 4 Bytes Flags vor den Kind-Atomen
        final innerStart = (type == 'meta' && dataSize >= 4) ? dataStart + 4 : dataStart;
        _scanAtoms(bytes, innerStart, atomEnd, onAtom);
      }

      offset += size;
    }
  }

  /// Extrahiert Text aus einem typischen QuickTime 'data' Sub-Atom.
  String? _extractStringFromDataAtom(Uint8List bytes, int offset, int size) {
    // Suche nach Sub-Atom 'data'
    var p = offset;
    final end = offset + size;
    while (p + 16 <= end) {
      final subSize = _readUint32(bytes, p);
      if (subSize < 8 || p + subSize > end) break;
      final subType = _readFourCC(bytes, p + 4);

      if (subType == 'data') {
        // Data-Atom Header: 4 Bytes Size, 4 Bytes 'data', 4 Bytes Type/Flags, 4 Bytes Locale
        final payloadStart = p + 16;
        final payloadSize = subSize - 16;
        if (payloadSize > 0 && payloadStart + payloadSize <= end) {
          final strBytes = bytes.sublist(payloadStart, payloadStart + payloadSize);
          return utf8.decode(strBytes, allowMalformed: true).replaceAll('\x00', '').trim();
        }
      }
      p += subSize;
    }
    return null;
  }

  int? _extractTrackNumber(Uint8List bytes, int offset, int size) {
    var p = offset;
    final end = offset + size;
    while (p + 16 <= end) {
      final subSize = _readUint32(bytes, p);
      if (subSize < 8 || p + subSize > end) break;
      final subType = _readFourCC(bytes, p + 4);
      if (subType == 'data') {
        final payloadStart = p + 16;
        // In QuickTime trkn data: Bytes 18-19 (0-basiert ab data start) oder Bytes 2-3 des Payloads
        if (payloadStart + 4 <= end) {
          final track = (bytes[payloadStart + 2] << 8) | bytes[payloadStart + 3];
          if (track > 0) return track;
        }
      }
      p += subSize;
    }
    return null;
  }

  (Uint8List, String)? _extractCover(Uint8List bytes, int offset, int size) {
    var p = offset;
    final end = offset + size;
    while (p + 16 <= end) {
      final subSize = _readUint32(bytes, p);
      if (subSize < 8 || p + subSize > end) break;
      final subType = _readFourCC(bytes, p + 4);
      if (subType == 'data') {
        final typeIndicator = bytes[p + 11]; // 13 = JPEG, 14 = PNG
        final mime = typeIndicator == 14 ? 'image/png' : 'image/jpeg';
        final payloadStart = p + 16;
        final payloadSize = subSize - 16;
        if (payloadSize > 0 && payloadStart + payloadSize <= end) {
          final coverData = bytes.sublist(payloadStart, payloadStart + payloadSize);
          return (coverData, mime);
        }
      }
      p += subSize;
    }
    return null;
  }

  /// Parst das Nero 'chpl' Kapitel-Atom.
  void _parseChplAtom(
    Uint8List bytes,
    int offset,
    int size,
    List<Chapter> chapters,
  ) {
    try {
      if (size < 8) return;
      // Version(1 Byte) + Flags(3 Bytes) + Reserved(1 Byte) + EntryCount(4 oder 1+3 Bytes)
      final entryCount = _readUint32(bytes, offset + 4);
      var p = offset + 8;
      final end = offset + size;

      final rawEntries = <(Duration, String)>[];

      for (var i = 0; i < entryCount && p + 9 <= end; i++) {
        // Timestamp in 100ns-Einheiten
        final timestamp100ns = _readUint64(bytes, p);
        p += 8;
        final ms = timestamp100ns ~/ 10000;

        final titleLen = bytes[p];
        p += 1;
        if (p + titleLen > end) break;

        final titleStr = utf8.decode(
          bytes.sublist(p, p + titleLen),
          allowMalformed: true,
        );
        p += titleLen;

        rawEntries.add((Duration(milliseconds: ms), titleStr));
      }

      // Kapitelmarken mit passenden Start- und End-Zeiten erzeugen
      for (var i = 0; i < rawEntries.length; i++) {
        final start = rawEntries[i].$1;
        final title = rawEntries[i].$2;
        final end = (i + 1 < rawEntries.length)
            ? rawEntries[i + 1].$1
            : start + const Duration(minutes: 5); // Schaetzung fuer letztes Kapitel

        chapters.add(
          Chapter(
            id: 'm4b-chap-$i',
            title: title.isNotEmpty ? title : 'Kapitel ${i + 1}',
            start: start,
            end: end >= start ? end : start,
            index: i,
          ),
        );
      }
    } catch (_) {}
  }
}
