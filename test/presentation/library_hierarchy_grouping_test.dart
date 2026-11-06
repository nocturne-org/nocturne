import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/repositories/media_repository_impl.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/providers/library_providers.dart';
import 'package:nocturne/presentation/providers/repository_providers.dart';

void main() {
  group('Library Hierarchy Grouping Tests (Autor -> Alben -> Tracks)', () {
    late AppDatabase db;
    late MediaRepositoryImpl repo;
    late ProviderContainer container;

    // Autor 1, Album A, 2 Tracks
    final a1Track1 = MediaItem(
      id: 'a1_t1',
      title: 'Kapitel 1',
      author: 'Franz Kafka',
      album: 'Das Schloss',
      duration: const Duration(milliseconds: 1200000),
      source: AudioSourceRef.localFile(filePath: '/audio/kafka_schloss_1.mp3'),
    );
    final a1Track2 = MediaItem(
      id: 'a1_t2',
      title: 'Kapitel 2',
      author: 'Franz Kafka',
      album: 'Das Schloss',
      duration: const Duration(milliseconds: 1400000),
      source: AudioSourceRef.localFile(filePath: '/audio/kafka_schloss_2.mp3'),
    );

    // Autor 1, Album B, 1 Track
    final a1Track3 = MediaItem(
      id: 'a1_t3',
      title: 'Die Verwandlung Vollversion',
      author: 'Franz Kafka',
      album: 'Die Verwandlung',
      duration: const Duration(milliseconds: 5400000),
      source: AudioSourceRef.localFile(filePath: '/audio/kafka_verwandlung.m4b'),
    );

    // Autor 2, Album C, 1 Track
    final a2Track1 = MediaItem(
      id: 'a2_t1',
      title: 'Kapitel 1',
      author: 'Arthur Conan Doyle',
      album: 'Sherlock Holmes',
      duration: const Duration(milliseconds: 2500000),
      source: AudioSourceRef.localFile(filePath: '/audio/sherlock_1.mp3'),
    );

    setUp(() async {
      db = AppDatabase.memory();
      repo = MediaRepositoryImpl(db: db);

      await repo.batchImportMedia([a1Track1, a1Track2, a1Track3, a2Track1]);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('groupMediaHierarchically erzeugt vollstaendige 3-Ebenen-Hierarchie', () async {
      container.read(libraryBrowserControllerProvider);
      await pumpEventQueue();

      final state = container.read(libraryBrowserControllerProvider);
      final hierarchy = state.groupedByAuthor;

      // 2 Autoren
      expect(hierarchy.length, 2);

      // Autor 1: Arthur Conan Doyle (alphabetisch sortiert)
      final authorDoyle = hierarchy.firstWhere((a) => a.authorName == 'Arthur Conan Doyle');
      expect(authorDoyle.albums.length, 1);
      expect(authorDoyle.albums.first.albumTitle, 'Sherlock Holmes');
      expect(authorDoyle.albums.first.items.length, 1);
      expect(authorDoyle.totalTracks, 1);

      // Autor 2: Franz Kafka mit 2 Alben
      final authorKafka = hierarchy.firstWhere((a) => a.authorName == 'Franz Kafka');
      expect(authorKafka.albums.length, 2);
      expect(authorKafka.totalTracks, 3);

      final schlossAlbum = authorKafka.albums.firstWhere((a) => a.albumTitle == 'Das Schloss');
      expect(schlossAlbum.items.length, 2);
      expect(schlossAlbum.items[0].title, 'Kapitel 1');
      expect(schlossAlbum.items[1].title, 'Kapitel 2');
      expect(schlossAlbum.totalDurationMs, 1200000 + 1400000);

      final verwandlungAlbum = authorKafka.albums.firstWhere((a) => a.albumTitle == 'Die Verwandlung');
      expect(verwandlungAlbum.items.length, 1);
    });
  });
}
