import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/repositories/media_repository_impl.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/providers/library_providers.dart';
import 'package:nocturne/presentation/providers/repository_providers.dart';
import 'package:nocturne/presentation/state/library_browser_state.dart';

void main() {
  group('LibraryBrowserController Tests', () {
    late AppDatabase db;
    late MediaRepositoryImpl repo;
    late ProviderContainer container;

    // 1. Lokales Hoerbuch
    final audiobook1 = MediaItem(
      id: 'ab_01',
      title: 'Der Zauberberg - Kapitel 1',
      author: 'Thomas Mann',
      album: 'Der Zauberberg',
      duration: const Duration(milliseconds: 3600000),
      source: AudioSourceRef.localFile(filePath: '/storage/zauberberg_1.mp3'),
    );

    // 2. Weiteres lokales Hoerbuch desselben Autors
    final audiobook2 = MediaItem(
      id: 'ab_02',
      title: 'Buddenbrooks',
      author: 'Thomas Mann',
      album: 'Buddenbrooks',
      duration: const Duration(milliseconds: 7200000),
      source: AudioSourceRef.localFile(filePath: '/storage/buddenbrooks.m4b'),
    );

    // 3. Podcast Folge
    final podcast = MediaItem(
      id: 'pod_01',
      title: 'Episode 50: Schlafbiologie',
      author: 'Dr. Somnus',
      album: 'Schlaf gut Podcast',
      duration: const Duration(milliseconds: 1800000),
      source:
          AudioSourceRef.remoteStream(streamUrl: 'https://podcast.de/ep50.mp3'),
      extraMetadata: const {'podcast_title': 'Schlaf gut Podcast'},
    );

    // 4. YouTube Audio Stream
    final youtube = MediaItem(
      id: 'yt_01',
      title: 'White Noise for Deep Sleep 8h',
      author: 'Sleep Laboratory',
      album: 'Sleep Sounds',
      duration: const Duration(milliseconds: 28800000),
      source:
          AudioSourceRef.remoteStream(streamUrl: 'https://youtube.com/stream'),
    );

    setUp(() async {
      db = AppDatabase.memory();
      repo = MediaRepositoryImpl(db: db);

      await repo.batchImportMedia([audiobook1, audiobook2, podcast, youtube]);

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

    test('Initialer Zustand laedt alle Medien', () async {
      container.read(libraryBrowserControllerProvider);
      await pumpEventQueue();

      final state = container.read(libraryBrowserControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.items.length, 4);
      expect(state.filteredItems.length, 4);
    });

    test('setSearchQuery filtert nach Volltext ueber Titel, Autor und Album',
        () async {
      final controller =
          container.read(libraryBrowserControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Suche nach Autor 'Thomas Mann'
      controller.setSearchQuery('Thomas');
      var state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 2);
      expect(
          state.filteredItems.every((i) => i.author == 'Thomas Mann'), isTrue);

      // Suche nach Album 'Schlaf gut'
      controller.setSearchQuery('schlaf gut');
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 1);
      expect(state.filteredItems.first.id, podcast.id);

      // Leere Suche stellt alle wieder her
      controller.setSearchQuery('');
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 4);
    });

    test('Filterchips filtern praezise nach Medientyp und Offline-Status',
        () async {
      final controller =
          container.read(libraryBrowserControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 1. Nur Hoerbuecher
      controller.setFilter(LibraryFilterChipType.audiobooks);
      var state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 2);
      expect(state.filteredItems.every((i) => i.source.isLocal), isTrue);

      // 2. Nur Podcasts
      controller.setFilter(LibraryFilterChipType.podcasts);
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 1);
      expect(state.filteredItems.first.id, podcast.id);

      // 3. Nur YouTube
      controller.setFilter(LibraryFilterChipType.youtube);
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 1);
      expect(state.filteredItems.first.id, youtube.id);

      // 4. Nur Offline
      controller.setFilter(LibraryFilterChipType.offlineOnly);
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.length, 2);
    });

    test('setSortOrder sortiert nach Dauer absteigend und Titel aufsteigend',
        () async {
      final controller =
          container.read(libraryBrowserControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Sortierung nach Dauer absteigend
      controller.setSortOrder(LibrarySortOrder.durationDesc);
      var state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.first.id, youtube.id); // 8h
      expect(state.filteredItems.last.id, podcast.id); // 30min

      // Sortierung nach Titel alphabetisch
      controller.setSortOrder(LibrarySortOrder.titleAsc);
      state = container.read(libraryBrowserControllerProvider);
      expect(state.filteredItems.first.title, 'Buddenbrooks');
    });
  });
}
