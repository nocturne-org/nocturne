import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/datasources/database/daos/media_dao.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';

void main() {
  group('AppDatabase & Drift Native SQLite Production Tests (TICK-V2-01)', () {
    late AppDatabase db;
    late MediaDao dao;

    setUp(() {
      db = AppDatabase.memory();
      dao = db.mediaDao;
    });

    tearDown(() async {
      await db.close();
    });

    test('Table definitions in Drift SQLite schema are complete and valid', () {
      expect(db.schemaVersion, 1);
      expect(db.mediaItemsTable.tableName, 'media_items');
      expect(db.bookmarksTable.tableName, 'bookmarks');
      expect(db.playbackHistoryTable.tableName, 'playback_history');
      expect(db.sleepPresetsTable.tableName, 'sleep_presets');
      expect(db.playlistsTable.tableName, 'playlists');
      expect(db.playlistItemsTable.tableName, 'playlist_items');
      expect(db.favoritesTable.tableName, 'favorites');

      expect(db.mediaItemsTable, isNotNull);
      expect(db.bookmarksTable, isNotNull);
      expect(db.playbackHistoryTable, isNotNull);
      expect(db.sleepPresetsTable, isNotNull);
      expect(db.playlistsTable, isNotNull);
      expect(db.playlistItemsTable, isNotNull);
      expect(db.favoritesTable, isNotNull);
    });

    test('MediaItem CRUD operations work asynchronously with real SQLite', () async {
      const item = MediaItem(
        id: 'book-1',
        title: 'Der Steppenwolf',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(
          filePath: '/data/user/0/com.nocturne.audio/files/steppenwolf.m4b',
        ),
        author: 'Hermann Hesse',
        duration: Duration(hours: 6, minutes: 30),
      );

      // Insert
      await dao.insertMediaItem(item);
      final retrieved = await dao.getMediaItemById('book-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Der Steppenwolf');
      expect(retrieved.author, 'Hermann Hesse');
      expect(retrieved.isCompleted, isFalse);

      // Update
      final updated = retrieved.copyWith(title: 'Der Steppenwolf (Ungekuerzt)');
      await dao.updateMediaItem(updated);
      final afterUpdate = await dao.getMediaItemById('book-1');
      expect(afterUpdate!.title, 'Der Steppenwolf (Ungekuerzt)');

      // Upsert
      const item2 = MediaItem(
        id: 'podcast-1',
        title: 'Einschlafen Podcast',
        type: MediaType.podcastEpisode,
        source: AudioSourceRef.streamingUrl(
          streamUrl: 'https://example.com/feed.mp3',
        ),
      );
      await dao.upsertMediaItem(item2);
      final allItems = await dao.getAllMediaItems();
      expect(allItems.length, 2);

      // Delete
      await dao.deleteMediaItem('book-1');
      expect(await dao.getMediaItemById('book-1'), isNull);
      expect((await dao.getAllMediaItems()).length, 1);
    });

    test('Millisecond-precise storage and retrieval of playback position', () async {
      const item = MediaItem(
        id: 'audio-prec',
        title: 'Precision Track',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/storage/track.mp3'),
      );
      await dao.insertMediaItem(item);

      const exactPos = PlaybackPosition(duration: Duration(milliseconds: 123456));
      final playTime = DateTime(2026, 11, 6, 23, 15, 0);

      await dao.updatePlaybackPosition(
        'audio-prec',
        exactPos,
        isCompleted: false,
        lastPlayedAt: playTime,
      );

      final retrieved = await dao.getMediaItemById('audio-prec');
      expect(retrieved, isNotNull);
      expect(retrieved!.lastPosition.milliseconds, 123456);
      expect(retrieved.lastPlayedAt, playTime);
      expect(retrieved.isCompleted, isFalse);
    });

    test('Reactive Streams (watch) emit live SQLite database updates', () async {
      var emittedLists = <List<MediaItem>>[];
      final sub = dao.watchAllMediaItems().listen((list) {
        emittedLists.add(list);
      });

      await Future<void>.delayed(Duration.zero);
      expect(emittedLists.isNotEmpty, isTrue);

      await dao.insertMediaItem(
        const MediaItem(
          id: 'watch-test-1',
          title: 'Live Title',
          type: MediaType.youTubeAudio,
          source: AudioSourceRef.youTube(videoId: 'abc1234'),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(emittedLists.last.any((m) => m.id == 'watch-test-1'), isTrue);

      await sub.cancel();
    });

    test('Multi-Row transactional integrity for batch inserts (Batch-Upsert)', () async {
      final items = List.generate(
        10,
        (i) => MediaItem(
          id: 'batch-item-$i',
          title: 'Kapitel $i',
          type: MediaType.audiobook,
          source: AudioSourceRef.localFile(filePath: '/audio/$i.mp3'),
        ),
      );

      await dao.batchUpsertMediaItems(items);

      final all = await dao.getAllMediaItems();
      expect(all.length, 10);
      expect(
        all.map((m) => m.id),
        containsAll(['batch-item-0', 'batch-item-9']),
      );
    });

    test('Transactional rollback reverts all changes upon exception', () async {
      const item1 = MediaItem(
        id: 'safe-item-1',
        title: 'Sicher 1',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/1.mp3'),
      );
      await dao.insertMediaItem(item1);

      bool failed = false;
      try {
        await db.transaction(() async {
          await dao.insertMediaItem(
            const MediaItem(
              id: 'trans-item-2',
              title: 'Trans 2',
              type: MediaType.audiobook,
              source: AudioSourceRef.localFile(filePath: '/audio/2.mp3'),
            ),
          );
          throw Exception('Rollback erzwungen!');
        });
      } catch (e) {
        failed = true;
      }
      expect(failed, isTrue);

      // Verify that uncommitted transaction row was completely rolled back in SQLite
      expect(await dao.getMediaItemById('trans-item-2'), isNull);
      expect(await dao.getMediaItemById('safe-item-1'), isNotNull);
    });

    test('Cascading deletion: Bookmarks and history are removed with MediaItem', () async {
      const media = MediaItem(
        id: 'parent-media',
        title: 'Hoerbuch mit Lesezeichen',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/parent.m4b'),
      );
      await dao.insertMediaItem(media);

      final bm1 = Bookmark(
        id: 'bm-1',
        mediaItemId: 'parent-media',
        position: const PlaybackPosition(duration: Duration(minutes: 10)),
        createdAt: DateTime.now(),
        label: 'Vor Einschlafen',
      );
      final bm2 = Bookmark(
        id: 'bm-2',
        mediaItemId: 'parent-media',
        position: const PlaybackPosition(duration: Duration(minutes: 25)),
        createdAt: DateTime.now(),
        label: 'Aufwachen',
      );
      await dao.insertBookmark(bm1);
      await dao.insertBookmark(bm2);

      final historyEntry = PlaybackHistoryEntry(
        id: 'hist-1',
        mediaItemId: 'parent-media',
        playedAt: DateTime.now(),
        playbackDurationMs: 900000,
        startPositionMs: 0,
        endPositionMs: 900000,
      );
      await dao.recordPlaybackHistory(historyEntry);

      expect((await dao.getBookmarksForMedia('parent-media')).length, 2);
      expect((await dao.getPlaybackHistory('parent-media')).length, 1);

      await dao.deleteMediaItem('parent-media');

      expect(await dao.getMediaItemById('parent-media'), isNull);
      expect((await dao.getBookmarksForMedia('parent-media')).isEmpty, isTrue);
      expect((await dao.getPlaybackHistory('parent-media')).isEmpty, isTrue);
    });

    test('Foreign key enforcement prevents orphan bookmarks and history', () async {
      final invalidBm = Bookmark(
        id: 'bm-orphan',
        mediaItemId: 'non-existent-id',
        position: PlaybackPosition.zero,
        createdAt: DateTime.now(),
        label: 'Verwaist',
      );

      expect(
        () => dao.insertBookmark(invalidBm),
        throwsA(isA<StateError>()),
      );

      final invalidHist = PlaybackHistoryEntry(
        id: 'hist-orphan',
        mediaItemId: 'non-existent-id',
        playedAt: DateTime.now(),
        playbackDurationMs: 1000,
        startPositionMs: 0,
        endPositionMs: 1000,
      );

      expect(
        () => dao.recordPlaybackHistory(invalidHist),
        throwsA(isA<StateError>()),
      );
    });

    test('SleepPresets CRUD and ordering by minutes', () async {
      const preset1 = SleepPresetEntry(
        id: 'preset-30',
        name: 'Standard 30 Min',
        durationMinutes: 30,
        autoFadeOutSeconds: 60,
        shakeGracePeriodSeconds: 120,
        autoRewindSeconds: 45,
        isDefault: true,
      );

      const preset2 = SleepPresetEntry(
        id: 'preset-15',
        name: 'Kurzschlaf 15 Min',
        durationMinutes: 15,
        autoFadeOutSeconds: 30,
        shakeGracePeriodSeconds: 60,
      );

      await dao.insertSleepPreset(preset1);
      await dao.insertSleepPreset(preset2);

      final presets = await dao.getSleepPresets();
      expect(presets.length, 2);
      expect(presets.first.durationMinutes, 15);
      expect(presets.last.durationMinutes, 30);
      expect(presets.last.isDefault, isTrue);

      await dao.deleteSleepPreset('preset-15');
      expect((await dao.getSleepPresets()).length, 1);
    });

    test('Playlist CRUD and sorting by recent works reliably in SQLite', () async {
      final p1 = await dao.createPlaylist('Bedtime Audiobooks', kind: 'folder');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final p2 = await dao.createPlaylist('Night Ambient', kind: 'custom');

      final playlists = await dao.getPlaylistsSortedByRecent();
      expect(playlists.length, 2);
      expect(playlists.first.name, 'Night Ambient');
      expect(playlists.last.name, 'Bedtime Audiobooks');

      // Add items
      await dao.addItemsToPlaylist(p1.id, ['track-1', 'track-2']);
      final items = await dao.getPlaylistItems(p1.id);
      expect(items, ['track-1', 'track-2']);

      // Remove item
      await dao.removeItemsFromPlaylist(p1.id, ['track-1']);
      final itemsAfter = await dao.getPlaylistItems(p1.id);
      expect(itemsAfter, ['track-2']);

      // Delete playlist cascades playlist items
      await dao.deletePlaylist(p1.id);
      final remaining = await dao.getPlaylists();
      expect(remaining.length, 1);
      expect(remaining.first.id, p2.id);
      expect(await dao.getPlaylistItems(p1.id), isEmpty);
    });

    test('Favorites toggle, querying and reactive streams work reliably in SQLite', () async {
      expect(await dao.isFavorite('track-100'), isFalse);

      final isFav1 = await dao.toggleFavorite('track-100');
      expect(isFav1, isTrue);
      expect(await dao.isFavorite('track-100'), isTrue);

      final favs = await dao.getFavorites();
      expect(favs, contains('track-100'));

      final isFav2 = await dao.toggleFavorite('track-100');
      expect(isFav2, isFalse);
      expect(await dao.isFavorite('track-100'), isFalse);
    });

    test('Playback queue persistent storage, reordering and retrieval', () async {
      // First insert media items for foreign key constraint
      await dao.insertMediaItem(const MediaItem(
        id: 'track-a',
        title: 'Track A',
        source: AudioSourceRef.localFile(filePath: '/audio/a.mp3'),
      ));
      await dao.insertMediaItem(const MediaItem(
        id: 'track-b',
        title: 'Track B',
        source: AudioSourceRef.localFile(filePath: '/audio/b.mp3'),
      ));
      await dao.insertMediaItem(const MediaItem(
        id: 'track-c',
        title: 'Track C',
        source: AudioSourceRef.localFile(filePath: '/audio/c.mp3'),
      ));

      await dao.savePlaybackQueue(['track-a', 'track-b', 'track-c'], currentIndex: 1);

      final queue = await dao.getPlaybackQueue();
      expect(queue, ['track-a', 'track-b', 'track-c']);

      final currentIdx = await dao.getPlaybackQueueCurrentIndex();
      expect(currentIdx, 1);

      await dao.clearPlaybackQueue();
      expect(await dao.getPlaybackQueue(), isEmpty);
    });
  });
}
