import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/download/download_manager.dart';
import 'package:nocturne/data/download/download_task.dart';
import 'package:nocturne/data/repositories/media_repository.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';
import 'package:nocturne/platform/storage/sandbox_storage_provider.dart';

class MockSpaceResolver implements StorageSpaceResolver {
  MockSpaceResolver(this.freeSpace);
  int freeSpace;

  @override
  Future<int> getFreeDiskSpace(String path) async => freeSpace;
}

class InMemoryMediaRepository implements MediaRepository {
  final Map<String, MediaItem> items = {};

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
  }) async {}

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

class MockDownloadHttpTransport implements DownloadHttpTransport {
  MockDownloadHttpTransport({
    this.simulatedBytes = 1024 * 1024,
    this.delay = Duration.zero,
    this.shouldThrow = false,
  });

  final int simulatedBytes;
  final Duration delay;
  final bool shouldThrow;

  @override
  Future<void> downloadStream({
    required String url,
    required File targetPartFile,
    required void Function(int downloaded, int total) onProgress,
    required bool Function() isCancelledOrPaused,
  }) async {
    if (shouldThrow) {
      throw const SocketException('Netzwerkfehler');
    }

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (isCancelledOrPaused()) return;

    final dummyData = List.filled(simulatedBytes, 0x42);
    await targetPartFile.writeAsBytes(dummyData);
    onProgress(simulatedBytes, simulatedBytes);
  }
}

void main() {
  group('DownloadManager Tests', () {
    late Directory tempDir;
    late MockSpaceResolver mockSpaceResolver;
    late SandboxStorageProvider storageProvider;
    late InMemoryMediaRepository mediaRepo;
    late DownloadManager manager;

    final testMediaItem = MediaItem(
      id: 'item_test_001',
      title: 'Schlaf gut Podcast',
      author: 'Nocturne Studio',
      album: 'Gute Nacht Geschichten',
      duration: const Duration(milliseconds: 3600000),
      source: AudioSourceRef.remoteStream(
        streamUrl: 'https://example.com/audio/test.m4a',
      ),
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('download_mgr_test_');
      mockSpaceResolver = MockSpaceResolver(2 * 1024 * 1024 * 1024); // 2 GB frei
      storageProvider = SandboxStorageProvider(
        baseDirectory: tempDir,
        spaceResolver: mockSpaceResolver,
      );
      await storageProvider.initialize();
      mediaRepo = InMemoryMediaRepository();
      manager = DownloadManager(
        storageProvider: storageProvider,
        mediaRepository: mediaRepo,
        transport: MockDownloadHttpTransport(),
      );
    });

    tearDown(() async {
      await manager.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('enqueueDownload startet und fuehrt Download vollstaendig aus', () async {
      final task = await manager.enqueueDownload(
        mediaItem: testMediaItem,
        streamUrl: 'https://example.com/audio/test.m4a',
        estimatedSizeBytes: 1024 * 1024,
      );

      expect(task.id, 'item_test_001');
      expect(task.targetPath, contains('audio_downloads'));
      expect(task.targetPath.endsWith('item_test_001.m4a'), isTrue);

      // Warten bis der asynchrone Download durchlaeuft
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Finaler Zustand in der Queue pruefen
      final queueState = await manager.watchQueue().first;
      final completedTask = queueState.firstWhere((t) => t.id == task.id);
      expect(completedTask.status, DownloadStatus.completed);

      // Zieldatei muss existieren
      final finalFile = File(completedTask.targetPath);
      expect(await finalFile.exists(), isTrue);

      // .part Datei muss aufgeraeumt sein
      final partFile = File(completedTask.partPath);
      expect(await partFile.exists(), isFalse);

      // Medienrepository muss die lokale Version enthalten
      final savedItem = await mediaRepo.getMediaById('item_test_001');
      expect(savedItem, isNotNull);
      expect(savedItem!.source.isLocal, isTrue);
      expect(savedItem.source.uri, completedTask.targetPath);
    });

    test('enqueueDownload wirft Fehler bei unzureichendem Speicherplatz', () async {
      mockSpaceResolver.freeSpace = 100 * 1024 * 1024; // nur 100 MB frei

      expect(
        () => manager.enqueueDownload(
          mediaItem: testMediaItem,
          streamUrl: 'https://example.com/audio/test.m4a',
          estimatedSizeBytes: 200 * 1024 * 1024,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('cancelDownload loescht die temporaere part-Datei', () async {
      final delayedManager = DownloadManager(
        storageProvider: storageProvider,
        mediaRepository: mediaRepo,
        transport: MockDownloadHttpTransport(
          delay: const Duration(milliseconds: 500),
        ),
      );

      final task = await delayedManager.enqueueDownload(
        mediaItem: testMediaItem,
        streamUrl: 'https://example.com/audio/test.m4a',
      );

      // Sofort abbrechen
      await delayedManager.cancelDownload(task.id);

      final queueState = await delayedManager.watchQueue().first;
      final cancelled = queueState.firstWhere((t) => t.id == task.id);
      expect(cancelled.status, DownloadStatus.cancelled);

      // Part file darf nicht mehr existieren
      final partFile = File(task.partPath);
      expect(await partFile.exists(), isFalse);

      await delayedManager.dispose();
    });

    test('Fehlerhafter Download markiert Task als failed', () async {
      final failingManager = DownloadManager(
        storageProvider: storageProvider,
        mediaRepository: mediaRepo,
        transport: MockDownloadHttpTransport(shouldThrow: true),
      );

      final task = await failingManager.enqueueDownload(
        mediaItem: testMediaItem,
        streamUrl: 'https://example.com/audio/test.m4a',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final queueState = await failingManager.watchQueue().first;
      final failedTask = queueState.firstWhere((t) => t.id == task.id);
      expect(failedTask.status, DownloadStatus.failed);
      expect(failedTask.errorMessage, isNotNull);

      await failingManager.dispose();
    });
  });
}
