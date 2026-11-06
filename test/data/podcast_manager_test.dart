import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/download/download_manager.dart';
import 'package:nocturne/data/download/download_task.dart';
import 'package:nocturne/data/podcast/podcast_manager.dart';
import 'package:nocturne/data/podcast/podcast_models.dart';
import 'package:nocturne/data/repositories/media_repository.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';
import 'package:nocturne/platform/storage/sandbox_storage_provider.dart';

class MockPodcastHttpFetcher implements PodcastHttpFetcher {
  MockPodcastHttpFetcher(this.xmlResponse);
  final String xmlResponse;

  @override
  Future<String> fetchXml(String url) async => xmlResponse;
}

class MockPodcastSpaceResolver implements StorageSpaceResolver {
  MockPodcastSpaceResolver(this.freeSpace);
  int freeSpace;

  @override
  Future<int> getFreeDiskSpace(String path) async => freeSpace;
}

class FakeMediaRepository implements MediaRepository {
  final Map<String, MediaItem> items = {};
  final Map<String, PlaybackPosition> positions = {};
  final Map<String, bool> completionStatus = {};

  @override
  Future<void> saveMedia(MediaItem item) async {
    items[item.id] = item;
  }

  @override
  Future<MediaItem?> getMediaById(String id) async => items[id];

  @override
  Future<List<MediaItem>> getAllMedia() async => items.values.toList();

  @override
  Stream<List<MediaItem>> watchAllMedia() =>
      Stream.value(items.values.toList());

  @override
  Stream<MediaItem?> watchMediaById(String id) =>
      Stream.value(items[id]);

  @override
  Future<void> deleteMedia(String id) async {
    items.remove(id);
  }

  @override
  Future<void> updatePosition(
    String id,
    PlaybackPosition position, {
    bool? isCompleted,
    DateTime? lastPlayedAt,
  }) async {
    positions[id] = position;
    if (isCompleted != null) {
      completionStatus[id] = isCompleted;
    }
  }

  @override
  Future<void> batchImportMedia(List<MediaItem> items) async {
    for (final it in items) {
      this.items[it.id] = it;
    }
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) async {}

  @override
  Future<void> deleteBookmark(String id) async {}

  @override
  Stream<List<Bookmark>> watchBookmarks(String mediaItemId) =>
      Stream.value([]);

  final List<String> _queue = [];
  int _queueIndex = 0;

  @override
  Future<void> savePlaybackQueue(List<String> mediaItemIds, {int currentIndex = 0}) async {
    _queue.clear();
    _queue.addAll(mediaItemIds);
    _queueIndex = currentIndex;
  }

  @override
  Future<List<String>> loadPlaybackQueue() async => List.unmodifiable(_queue);

  @override
  Future<int> loadPlaybackQueueCurrentIndex() async => _queueIndex;

  @override
  Stream<List<String>> watchPlaybackQueue() => Stream.value(List.unmodifiable(_queue));

  @override
  Future<void> clearPlaybackQueue() async {
    _queue.clear();
    _queueIndex = 0;
  }
}

class DirectMockTransport implements DownloadHttpTransport {
  @override
  Future<void> downloadStream({
    required String url,
    required File targetPartFile,
    required void Function(int downloaded, int total) onProgress,
    required bool Function() isCancelledOrPaused,
  }) async {
    await targetPartFile.writeAsBytes(List.filled(1000, 0x11));
    onProgress(1000, 1000);
  }
}

void main() {
  group('PodcastManager Tests', () {
    const validXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Schlaf gut Welt</title>
    <description>Entspannung pur</description>
    <link>https://example.com</link>
    <item>
      <title>Episode 10: Traumreise</title>
      <guid>ep-10</guid>
      <enclosure url="https://example.com/ep10.mp3" length="12345" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

    late FakeMediaRepository mediaRepo;
    late Directory tempDir;
    late SandboxStorageProvider storage;
    late DownloadManager downloadManager;
    late PodcastManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('podcast_mgr_test_');
      final resolver = MockPodcastSpaceResolver(2 * 1024 * 1024 * 1024);
      storage = SandboxStorageProvider(
        baseDirectory: tempDir,
        spaceResolver: resolver,
      );
      await storage.initialize();

      mediaRepo = FakeMediaRepository();
      downloadManager = DownloadManager(
        storageProvider: storage,
        mediaRepository: mediaRepo,
        transport: DirectMockTransport(),
      );

      manager = PodcastManager(
        mediaRepository: mediaRepo,
        httpFetcher: MockPodcastHttpFetcher(validXml),
        downloadManager: downloadManager,
      );
    });

    tearDown(() async {
      await manager.dispose();
      await downloadManager.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fetchFeed ruft XML ab und parst Feed-Struktur', () async {
      final feed = await manager.fetchFeed('https://example.com/feed.xml');
      expect(feed.title, 'Schlaf gut Welt');
      expect(feed.episodes.length, 1);
      expect(feed.episodes.first.title, 'Episode 10: Traumreise');
    });

    test('subscribe speichert Episoden als MediaItems in die Drift-Bibliothek', () async {
      final feed = await manager.subscribe('https://example.com/feed.xml');
      expect(manager.subscribedFeeds.length, 1);

      // Pruefen, ob MediaRepository die Episode enthaelt
      final allMedia = await mediaRepo.getAllMedia();
      expect(allMedia.length, 1);
      expect(allMedia.first.title, 'Episode 10: Traumreise');
      expect(allMedia.first.album, 'Schlaf gut Welt');
    });

    test('unsubscribe entfernt Feed aus den aktiven Abonnements', () async {
      await manager.subscribe('https://example.com/feed.xml');
      expect(manager.subscribedFeeds.length, 1);

      await manager.unsubscribe('https://example.com/feed.xml');
      expect(manager.subscribedFeeds.isEmpty, isTrue);
    });

    test('downloadEpisode queued und laedt Episode in die Offline-Sandbox herunter', () async {
      final feed = await manager.subscribe('https://example.com/feed.xml');
      final episode = feed.episodes.first;

      final task = await manager.downloadEpisode(
        episode,
        podcastTitle: feed.title,
      );

      expect(task.id, episode.id);
      expect(task.status, DownloadStatus.queued);

      // Warten bis der Download im Mock-Transport abgeschlossen ist
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final queue = await downloadManager.watchQueue().first;
      final completed = queue.firstWhere((t) => t.id == task.id);
      expect(completed.status, DownloadStatus.completed);

      // Pruefen, ob die Datei in der Sandbox liegt
      final file = File(completed.targetPath);
      expect(await file.exists(), isTrue);
    });

    test('markEpisodePlayed aktualisiert Wiedergabestatus in MediaRepository', () async {
      await manager.markEpisodePlayed('test_ep_001');
      expect(mediaRepo.completionStatus['test_ep_001'], isTrue);
    });
  });
}
