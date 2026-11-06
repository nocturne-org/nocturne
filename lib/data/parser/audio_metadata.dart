import 'dart:typed_data';
import '../../domain/models/chapter.dart';

/// Extrahierte Metadaten einer Audio-Datei (ID3 oder M4B).
class AudioMetadata {
  const AudioMetadata({
    required this.title,
    this.author,
    this.album,
    this.trackNumber,
    this.year,
    this.duration,
    this.coverArtBytes,
    this.coverMimeType,
    this.chapters = const [],
    this.rawFormat = 'unknown',
  });

  /// Titel des Hoerbuchs oder der Episode.
  final String title;

  /// Kuenstler, Sprecher oder Autor.
  final String? author;

  /// Album, Buchname oder Podcast-Reihe.
  final String? album;

  /// Track- bzw. Kapitelnummer.
  final int? trackNumber;

  /// Erscheinungsjahr.
  final int? year;

  /// Gesamtdauer des Mediums.
  final Duration? duration;

  /// Rohdaten des eingebetteten Coverbildes (JPEG oder PNG).
  final Uint8List? coverArtBytes;

  /// MIME-Type des Covers (z. B. "image/jpeg", "image/png").
  final String? coverMimeType;

  /// Eingebettete Kapitelmarken.
  final List<Chapter> chapters;

  /// Quellformat (z. B. "ID3v2", "ID3v1", "M4B/MP4", "Filename-Fallback").
  final String rawFormat;

  /// Ob ein eingebettetes Cover vorhanden ist.
  bool get hasCover => coverArtBytes != null && coverArtBytes!.isNotEmpty;

  /// Ob Kapitelmarken extrahiert wurden.
  bool get hasChapters => chapters.isNotEmpty;

  AudioMetadata copyWith({
    String? title,
    String? author,
    String? album,
    int? trackNumber,
    int? year,
    Duration? duration,
    Uint8List? coverArtBytes,
    String? coverMimeType,
    List<Chapter>? chapters,
    String? rawFormat,
  }) {
    return AudioMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      album: album ?? this.album,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      coverArtBytes: coverArtBytes ?? this.coverArtBytes,
      coverMimeType: coverMimeType ?? this.coverMimeType,
      chapters: chapters ?? this.chapters,
      rawFormat: rawFormat ?? this.rawFormat,
    );
  }

  @override
  String toString() {
    return 'AudioMetadata(title: "$title", author: "$author", album: "$album", track: $trackNumber, year: $year, chapters: ${chapters.length}, cover: $hasCover, format: $rawFormat)';
  }
}
