import 'audio/audio_source_ref.dart';
import 'chapter.dart';
import 'playback_position.dart';

/// Unterstuetzte Medientypen in Nocturne.
enum MediaType {
  /// Lokales oder importiertes Hoerbuch (z. B. M4B, MP3-Ordner).
  audiobook,

  /// Podcast-Episode aus einem RSS-Feed.
  podcastEpisode,

  /// Reiner Audio-Stream oder Download von YouTube.
  youTubeAudio,

  /// Video-Stream oder Video-Download von YouTube.
  youTubeVideo,
}

/// Zentrales Medienmodell im Domain-Layer.
/// Repraesentiert unabhaengig von Plattform und Speicherort ein abspielbares Audio- oder Video-Medium.
class MediaItem {
  /// Eindeutige Kennung des Mediums.
  final String id;

  /// Titel des Mediums oder der Episode.
  final String title;

  /// Spezifischer Medientyp.
  final MediaType type;

  /// Referenz auf die physische oder virtuelle Audioquelle.
  final AudioSourceRef source;

  /// Autor, Sprecher, Podcast-Host oder YouTube-Kanal.
  final String? author;

  /// Album, Buch-Reihe, Podcast-Show oder Playlist-Name.
  final String? album;

  /// Gesamtdauer des Mediums (null bei Live-Streams oder ungescannten Dateien).
  final Duration? duration;

  /// URI oder lokaler Pfad zum Cover-Bild.
  final String? coverArtUri;

  /// Liste aller (Unter-)Kapitel dieses Mediums.
  final List<Chapter> chapters;

  /// Zuletzt gespeicherte Abspielposition.
  final PlaybackPosition lastPosition;

  /// Kennzeichnung, ob das Medium vollstaendig angehoert wurde.
  final bool isCompleted;

  /// Zeitstempel der letzten Wiedergabe.
  final DateTime? lastPlayedAt;

  /// Zusaetzliche plattform- oder formatspezifische Metadaten (z. B. Bitrate, Format).
  final Map<String, dynamic> metadata;

  /// Erstellt ein unveraenderliches [MediaItem].
  const MediaItem({
    required this.id,
    required this.title,
    this.type = MediaType.audiobook,
    required this.source,
    this.author,
    this.album,
    this.duration,
    this.coverArtUri,
    this.chapters = const [],
    this.lastPosition = PlaybackPosition.zero,
    this.isCompleted = false,
    this.lastPlayedAt,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? extraMetadata,
  })  : metadata = metadata ?? extraMetadata ?? const {},
        assert(id.length > 0, 'MediaItem id must not be empty'),
        assert(title.length > 0, 'MediaItem title must not be empty');

  /// Gesamtdauer in Millisekunden (Convenience-Getter).
  int? get durationMs => duration?.inMilliseconds;

  /// Zusaetzliche Metadaten (Alias fuer metadata).
  Map<String, dynamic> get extraMetadata => metadata;

  /// Ob es sich um ein Hoerbuch handelt.
  bool get isAudiobook => type == MediaType.audiobook;

  /// Ob es sich um eine Podcast-Episode handelt.
  bool get isPodcast => type == MediaType.podcastEpisode;

  /// Ob es sich um YouTube-Audio handelt.
  bool get isYouTubeAudio => type == MediaType.youTubeAudio;

  /// Ob es sich um ein YouTube-Video handelt.
  bool get isYouTubeVideo => type == MediaType.youTubeVideo;

  /// Ob es sich um ein beliebiges YouTube-Medium handelt.
  bool get isYouTube => isYouTubeAudio || isYouTubeVideo;

  /// Ob Kapitelmarken fuer dieses Medium vorhanden sind.
  bool get hasChapters => chapters.isNotEmpty;

  /// Liefert das aktive Kapitel fuer eine gegebene Abspielposition.
  Chapter? getChapterAt(PlaybackPosition position) {
    for (final chapter in chapters) {
      final active = chapter.findActiveChapter(position);
      if (active != null) {
        return active;
      }
    }
    return null;
  }

  /// Berechnet den aktuellen Wiedergabefortschritt (0.0 bis 1.0).
  double get progressFraction {
    final d = duration;
    if (d == null || d.inMilliseconds <= 0) {
      return 0.0;
    }
    return lastPosition.progressFraction(d);
  }

  /// Erzeugt eine modifizierte Kopie dieses [MediaItem].
  MediaItem copyWith({
    String? id,
    String? title,
    MediaType? type,
    AudioSourceRef? source,
    String? author,
    String? album,
    Duration? duration,
    String? coverArtUri,
    List<Chapter>? chapters,
    PlaybackPosition? lastPosition,
    bool? isCompleted,
    DateTime? lastPlayedAt,
    Map<String, dynamic>? metadata,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      source: source ?? this.source,
      author: author ?? this.author,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverArtUri: coverArtUri ?? this.coverArtUri,
      chapters: chapters ?? this.chapters,
      lastPosition: lastPosition ?? this.lastPosition,
      isCompleted: isCompleted ?? this.isCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serialisiert das [MediaItem] in eine Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'source': source.toMap(),
      'author': author,
      'album': album,
      'durationMs': duration?.inMilliseconds,
      'coverArtUri': coverArtUri,
      'chapters': chapters.map((c) => c.toMap()).toList(),
      'lastPosition': lastPosition.toMap(),
      'isCompleted': isCompleted,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Deserialisiert ein [MediaItem] aus einer Map.
  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? MediaType.audiobook.name;
    final type = MediaType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MediaType.audiobook,
    );

    final rawChapters = map['chapters'] as List<dynamic>? ?? const [];
    final chapters = rawChapters
        .whereType<Map<String, dynamic>>()
        .map((c) => Chapter.fromMap(c))
        .toList();

    final durationMs = map['durationMs'] as num?;
    final lastPlayedStr = map['lastPlayedAt'] as String?;

    return MediaItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      type: type,
      source: AudioSourceRef.fromMap(
        (map['source'] as Map<String, dynamic>?) ?? {},
      ),
      author: map['author'] as String?,
      album: map['album'] as String?,
      duration: durationMs != null
          ? Duration(milliseconds: durationMs.toInt())
          : null,
      coverArtUri: map['coverArtUri'] as String?,
      chapters: List.unmodifiable(chapters),
      lastPosition: PlaybackPosition.fromMap(
        (map['lastPosition'] as Map<String, dynamic>?) ?? {},
      ),
      isCompleted: map['isCompleted'] as bool? ?? false,
      lastPlayedAt:
          lastPlayedStr != null ? DateTime.tryParse(lastPlayedStr) : null,
      metadata: Map<String, dynamic>.unmodifiable(
        (map['metadata'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaItem || runtimeType != other.runtimeType) return false;
    if (id != other.id ||
        title != other.title ||
        type != other.type ||
        source != other.source ||
        author != other.author ||
        album != other.album ||
        duration != other.duration ||
        coverArtUri != other.coverArtUri ||
        lastPosition != other.lastPosition ||
        isCompleted != other.isCompleted ||
        lastPlayedAt != other.lastPlayedAt ||
        chapters.length != other.chapters.length) {
      return false;
    }
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i] != other.chapters[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        type,
        source,
        author,
        album,
        duration,
        coverArtUri,
        lastPosition,
        isCompleted,
        lastPlayedAt,
        Object.hashAll(chapters),
      );

  @override
  String toString() =>
      'MediaItem(id: $id, title: "$title", type: ${type.name}, pos: ${lastPosition.formatProgress()})';
}
