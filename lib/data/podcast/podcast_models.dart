import '../../domain/models/audio/audio_source_ref.dart';
import '../../domain/models/media_item.dart';

/// Domaenenmodell fuer eine einzelne Podcast-Episode.
class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.guid,
    this.description = '',
    this.shownotes = '',
    this.pubDate,
    this.durationMs = 0,
    this.audioType = 'audio/mpeg',
    this.audioLengthBytes = 0,
    this.imageUrl,
    this.episodeNumber,
    this.seasonNumber,
    this.isPlayed = false,
    this.localFilePath,
  });

  /// Eindeutige Kennung (z. B. Hash von Feed-URL + GUID).
  final String id;

  /// GUID aus dem RSS-Item.
  final String? guid;

  /// Episodentitel.
  final String title;

  /// Kurzbeschreibung der Episode.
  final String description;

  /// Vollstaendige Shownotes (z. B. aus content:encoded).
  final String shownotes;

  /// Datum der Veroeffentlichung.
  final DateTime? pubDate;

  /// Gesamtdauer in Millisekunden.
  final int durationMs;

  /// URL des Audio-Streams (enclosure).
  final String audioUrl;

  /// MIME-Typ (z. B. audio/mpeg, audio/mp4).
  final String audioType;

  /// Dateigroesse in Bytes.
  final int audioLengthBytes;

  /// Episodencover-URL.
  final String? imageUrl;

  /// Episodennummer.
  final int? episodeNumber;

  /// Staffelnummer.
  final int? seasonNumber;

  /// Status, ob die Episode bereits vollstaendig angehoert wurde.
  final bool isPlayed;

  /// Lokaler Dateipfad falls die Episode offline heruntergeladen wurde.
  final String? localFilePath;

  /// Ob die Episode lokal offline verfuegbar ist.
  bool get isDownloaded => localFilePath != null && localFilePath!.isNotEmpty;

  /// Konvertierung in das allgemeine Nocturne MediaItem-Domaenenmodell.
  MediaItem toMediaItem({
    required String podcastTitle,
    String? feedAuthor,
  }) {
    final effectiveSource = isDownloaded
        ? AudioSourceRef.localFile(filePath: localFilePath!)
        : AudioSourceRef.remoteStream(
            streamUrl: audioUrl,
            headers: const {'User-Agent': 'NocturneAudio/1.0'},
          );

    return MediaItem(
      id: id,
      title: title,
      type: MediaType.podcastEpisode,
      author: feedAuthor ?? podcastTitle,
      album: podcastTitle,
      duration: Duration(milliseconds: durationMs),
      source: effectiveSource,
      coverArtUri: imageUrl,
      extraMetadata: {
        'podcast_title': podcastTitle,
        'guid': guid ?? id,
        'pub_date': pubDate?.toIso8601String() ?? '',
        'episode_number': episodeNumber?.toString() ?? '',
        'season_number': seasonNumber?.toString() ?? '',
        'audio_type': audioType,
      },
    );
  }

  PodcastEpisode copyWith({
    String? id,
    String? guid,
    String? title,
    String? description,
    String? shownotes,
    DateTime? pubDate,
    int? durationMs,
    String? audioUrl,
    String? audioType,
    int? audioLengthBytes,
    String? imageUrl,
    int? episodeNumber,
    int? seasonNumber,
    bool? isPlayed,
    String? localFilePath,
  }) {
    return PodcastEpisode(
      id: id ?? this.id,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      description: description ?? this.description,
      shownotes: shownotes ?? this.shownotes,
      pubDate: pubDate ?? this.pubDate,
      durationMs: durationMs ?? this.durationMs,
      audioUrl: audioUrl ?? this.audioUrl,
      audioType: audioType ?? this.audioType,
      audioLengthBytes: audioLengthBytes ?? this.audioLengthBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      isPlayed: isPlayed ?? this.isPlayed,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}

/// Domaenenmodell fuer einen abonnierten oder abgerufenen Podcast-Kanal.
class PodcastFeed {
  const PodcastFeed({
    required this.feedUrl,
    required this.title,
    this.description = '',
    this.author = '',
    this.link = '',
    this.imageUrl,
    this.language = 'de',
    this.episodes = const [],
  });

  /// URL des RSS-Feeds.
  final String feedUrl;

  /// Titel des Podcasts.
  final String title;

  /// Beschreibung des Podcasts.
  final String description;

  /// Autor oder Herausgeber.
  final String author;

  /// Webseiten-Link des Podcasts.
  final String link;

  /// Coverbild-URL des Podcasts.
  final String? imageUrl;

  /// Sprache des Feeds (z. B. de-DE oder en).
  final String language;

  /// Liste der enthaltenen Episoden.
  final List<PodcastEpisode> episodes;

  PodcastFeed copyWith({
    String? feedUrl,
    String? title,
    String? description,
    String? author,
    String? link,
    String? imageUrl,
    String? language,
    List<PodcastEpisode>? episodes,
  }) {
    return PodcastFeed(
      feedUrl: feedUrl ?? this.feedUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      link: link ?? this.link,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      episodes: episodes ?? this.episodes,
    );
  }
}
