import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';
import '../download/download_manager.dart';
import '../download/download_task.dart';
import '../repositories/media_repository.dart';
import 'podcast_feed_parser.dart';
import 'podcast_models.dart';

/// Schnittstelle fuer HTTP-Feed-Abfragen (entkoppelt fuer Unit-Tests).
abstract class PodcastHttpFetcher {
  Future<String> fetchXml(String url);
}

/// Standard-Fetcher fuer reale HTTP/HTTPS-Netzwerkabrufe.
class DefaultPodcastHttpFetcher implements PodcastHttpFetcher {
  const DefaultPodcastHttpFetcher();

  @override
  Future<String> fetchXml(String url) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'NocturneAudio/1.0 (Podcast Engine)');
      final response = await request.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await response.transform(utf8.decoder).join();
      } else {
        throw HttpException('HTTP-Fehler ${response.statusCode} beim Laden des RSS-Feeds.');
      }
    } finally {
      client.close();
    }
  }
}

/// Podcast-Manager zur Verwaltung von RSS-Abonnements, Episodenabrufen
/// und Synchronisation mit der lokalen Drift-Bibliothek und dem Download-Manager.
class PodcastManager {
  PodcastManager({
    required MediaRepository mediaRepository,
    PodcastHttpFetcher? httpFetcher,
    PodcastFeedParser? parser,
    DownloadManager? downloadManager,
  })  : _repo = mediaRepository,
        _fetcher = httpFetcher ?? const DefaultPodcastHttpFetcher(),
        _parser = parser ?? const PodcastFeedParser(),
        _downloadManager = downloadManager;

  final MediaRepository _repo;
  final PodcastHttpFetcher _fetcher;
  final PodcastFeedParser _parser;
  final DownloadManager? _downloadManager;

  final Set<String> _subscribedFeedUrls = {};
  final Map<String, PodcastFeed> _cachedFeeds = {};

  final StreamController<List<PodcastFeed>> _subscriptionsController =
      StreamController<List<PodcastFeed>>.broadcast();

  /// Reaktiv alle abonnierten Feeds beobachten.
  Stream<List<PodcastFeed>> watchSubscriptions() async* {
    yield _cachedFeeds.values.toList();
    yield* _subscriptionsController.stream;
  }

  /// Aktuelle Liste aller abonnierten Feeds.
  List<PodcastFeed> get subscribedFeeds => _cachedFeeds.values.toList();

  /// Ruft einen Feed von einer URL ab, parst ihn und gibt ihn zurueck.
  Future<PodcastFeed> fetchFeed(String feedUrl) async {
    final xmlContent = await _fetcher.fetchXml(feedUrl);
    final feed = _parser.parse(
      xmlContent: xmlContent,
      feedUrl: feedUrl,
    );
    _cachedFeeds[feedUrl] = feed;
    return feed;
  }

  /// Abonniert einen Podcast-Feed und synchronisiert die Episoden in die Bibliothek.
  Future<PodcastFeed> subscribe(String feedUrl) async {
    final feed = await fetchFeed(feedUrl);
    _subscribedFeedUrls.add(feedUrl);

    // Episoden als MediaItems in die Drift-Bibliothek importieren
    final mediaItems = feed.episodes.map((ep) {
      return ep.toMediaItem(
        podcastTitle: feed.title,
        feedAuthor: feed.author,
      );
    }).toList();

    await _repo.batchImportMedia(mediaItems);
    _notifySubscriptionsChanged();

    return feed;
  }

  /// Beendet das Abonnement eines Feeds.
  Future<void> unsubscribe(String feedUrl) async {
    _subscribedFeedUrls.remove(feedUrl);
    _cachedFeeds.remove(feedUrl);
    _notifySubscriptionsChanged();
  }

  /// Startet den Offline-Download einer Podcast-Episode.
  Future<DownloadTask> downloadEpisode(
    PodcastEpisode episode, {
    required String podcastTitle,
    String? feedAuthor,
  }) async {
    final dm = _downloadManager;
    if (dm == null) {
      throw StateError('Kein DownloadManager konfiguriert.');
    }

    final mediaItem = episode.toMediaItem(
      podcastTitle: podcastTitle,
      feedAuthor: feedAuthor,
    );

    return await dm.enqueueDownload(
      mediaItem: mediaItem,
      streamUrl: episode.audioUrl,
      estimatedSizeBytes: episode.audioLengthBytes > 0
          ? episode.audioLengthBytes
          : 30000000,
    );
  }

  /// Markiert eine Episode als vollstaendig angehoert.
  Future<void> markEpisodePlayed(String episodeId) async {
    await _repo.updatePosition(
      episodeId,
      PlaybackPosition.zero,
      isCompleted: true,
      lastPlayedAt: DateTime.now(),
    );
  }

  void _notifySubscriptionsChanged() {
    if (!_subscriptionsController.isClosed) {
      _subscriptionsController.add(_cachedFeeds.values.toList());
    }
  }

  Future<void> dispose() async {
    await _subscriptionsController.close();
  }
}
