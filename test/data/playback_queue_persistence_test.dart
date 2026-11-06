import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/repositories/media_repository_impl.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart';

void main() {
  group('PlaybackQueue Persistence Tests', () {
    late AppDatabase db;
    late MediaRepositoryImpl repo;

    final item1 = MediaItem(
      id: 'media_audiobook_1',
      title: 'Der Steppenwolf',
      author: 'Hermann Hesse',
      duration: const Duration(milliseconds: 7200000),
      source: AudioSourceRef.localFile(filePath: '/storage/steppenwolf.m4b'),
    );

    final item2 = MediaItem(
      id: 'media_podcast_2',
      title: 'Folge 42: Sternenhimmel',
      author: 'Astro Podcast',
      duration: const Duration(milliseconds: 3600000),
      source: AudioSourceRef.remoteStream(
          streamUrl: 'https://example.com/ep42.mp3'),
      extraMetadata: const {'podcast_title': 'Astro Podcast'},
    );

    final item3 = MediaItem(
      id: 'media_youtube_3',
      title: 'Rain on Tent 10h',
      author: 'Relaxing Sleep Sounds',
      duration: const Duration(milliseconds: 36000000),
      source: AudioSourceRef.remoteStream(
          streamUrl: 'https://rr2.googlevideo.com/audio'),
    );

    setUp(() async {
      db = AppDatabase.memory();
      repo = MediaRepositoryImpl(db: db);

      await repo.saveMedia(item1);
      await repo.saveMedia(item2);
      await repo.saveMedia(item3);
    });

    tearDown(() async {
      await db.close();
    });

    test('savePlaybackQueue speichert Queue-Reihenfolge und aktuellen Index',
        () async {
      await repo.savePlaybackQueue(
        [item1.id, item2.id, item3.id],
        currentIndex: 1,
      );

      final loadedQueue = await repo.loadPlaybackQueue();
      expect(loadedQueue, [item1.id, item2.id, item3.id]);

      final loadedIndex = await repo.loadPlaybackQueueCurrentIndex();
      expect(loadedIndex, 1);
    });

    test('watchPlaybackQueue reagiert auf Queue-Aktualisierungen', () async {
      final queueStream = repo.watchPlaybackQueue();

      final expectation = expectLater(
        queueStream,
        emitsInOrder([
          isEmpty,
          [item1.id, item2.id],
          [item3.id],
        ]),
      );

      await pumpEventQueue();

      await repo.savePlaybackQueue([item1.id, item2.id]);
      await repo.savePlaybackQueue([item3.id]);

      await expectation;
    });

    test('deleteMedia loescht Medium kaskadierend auch aus der PlaybackQueue',
        () async {
      await repo.savePlaybackQueue([item1.id, item2.id, item3.id]);

      // Loesche item2
      await repo.deleteMedia(item2.id);

      final queueAfterDelete = await repo.loadPlaybackQueue();
      expect(queueAfterDelete, [item1.id, item3.id]);
      expect(queueAfterDelete.contains(item2.id), isFalse);
    });

    test('clearPlaybackQueue leert die persistierte Warteschlange', () async {
      await repo.savePlaybackQueue([item1.id, item2.id]);
      expect((await repo.loadPlaybackQueue()).length, 2);

      await repo.clearPlaybackQueue();
      expect((await repo.loadPlaybackQueue()).isEmpty, isTrue);
    });
  });
}
