import 'dart:io';
import 'dart:typed_data';
import 'audio_metadata.dart';
import 'id3_parser.dart';
import 'm4b_parser.dart';

/// Zentraler Metadaten-Parser fuer ID3v1/ID3v2 und M4B/QuickTime mit
/// Cover-Extraktion und robustem Dateinamen-Fallback.
class MediaMetadataParser {
  const MediaMetadataParser({
    this.id3Parser = const Id3Parser(),
    this.m4bParser = const M4bParser(),
  });

  final Id3Parser id3Parser;
  final M4bParser m4bParser;

  /// Extrahiert Metadaten direkt aus einer Datei auf dem Speichermedium.
  Future<AudioMetadata> parseFile(File file) async {
    if (!await file.exists()) {
      return fallbackFromFileName(file.uri.pathSegments.last);
    }

    try {
      // Zunaechst die ersten 256 KB fuer Headers einlesen
      final length = await file.length();
      final headerSize = length > 262144 ? 262144 : length;
      final bytes =
          await file.openRead(0, headerSize).expand((b) => b).toList();
      final byteData = Uint8List.fromList(bytes);

      return parseBytes(byteData, file.uri.pathSegments.last);
    } catch (_) {
      return fallbackFromFileName(file.uri.pathSegments.last);
    }
  }

  /// Parst Metadaten aus einem Byte-Puffer.
  AudioMetadata parseBytes(Uint8List bytes, String fileName) {
    final cleanName = _cleanFileName(fileName);
    final ext = _extractExtension(fileName);

    AudioMetadata? parsed;

    // Format anhand Endung oder Magic-Bytes priorisieren
    if (ext == 'm4b' || ext == 'm4a' || ext == 'mp4') {
      parsed = m4bParser.parse(bytes, fallbackTitle: cleanName);
    } else if (ext == 'mp3') {
      parsed = id3Parser.parse(bytes, fallbackTitle: cleanName);
    } else {
      // Unbekannte Endung: Zuerst ID3, dann M4B versuchen
      parsed = id3Parser.parse(bytes, fallbackTitle: cleanName) ??
          m4bParser.parse(bytes, fallbackTitle: cleanName);
    }

    if (parsed == null || parsed.title.isEmpty) {
      return fallbackFromFileName(fileName);
    }

    return parsed;
  }

  /// Robuster Fallback auf den Dateinamen, falls Metadaten fehlen oder beschaedigt sind.
  AudioMetadata fallbackFromFileName(String fileName) {
    final clean = _cleanFileName(fileName);

    int? track;
    String title = clean;
    String? author;

    // Muster 1: "01 - Titel" oder "01. Titel"
    final trackMatch = RegExp(r'^(\d+)[\s._-]+(.+)$').firstMatch(clean);
    if (trackMatch != null) {
      track = int.tryParse(trackMatch.group(1)!);
      title = trackMatch.group(2)!.trim();
    } else {
      // Muster 2: "Autor - Titel"
      final authorMatch = RegExp(r'^([^-]+)-(.+)$').firstMatch(clean);
      if (authorMatch != null) {
        author = authorMatch.group(1)!.trim();
        title = authorMatch.group(2)!.trim();
      }
    }

    return AudioMetadata(
      title: title.isNotEmpty ? title : clean,
      author: author,
      trackNumber: track,
      rawFormat: 'Filename-Fallback',
    );
  }

  /// Speichert ein extrahiertes Coverbild im Cache-Verzeichnis ab.
  Future<File?> extractAndSaveCover(
    AudioMetadata metadata,
    Directory cacheDir,
    String mediaId,
  ) async {
    if (!metadata.hasCover) return null;

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final ext =
        (metadata.coverMimeType?.contains('png') ?? false) ? 'png' : 'jpg';
    final targetFile =
        File('${cacheDir.path}${Platform.pathSeparator}$mediaId.$ext');

    await targetFile.writeAsBytes(metadata.coverArtBytes!);
    return targetFile;
  }

  String _cleanFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1) {
      return fileName.substring(0, dotIndex).replaceAll('_', ' ').trim();
    }
    return fileName.replaceAll('_', ' ').trim();
  }

  String _extractExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < fileName.length - 1) {
      return fileName.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }
}
