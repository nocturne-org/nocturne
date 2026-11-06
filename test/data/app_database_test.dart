import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/datasources/database/daos/media_dao.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/chapter.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';

void main() {
  group('AppDatabase & Drift SQLite Schema Tests (TICK-003)', () {
    late AppDatabase db;
    late MediaDao dao;

    setUp(() {
      db = AppDatabase.memory();
      dao = db.mediaDao;
    });

    tearDown(() async {
      await db.close();
    });

    test('Tabellen-Definitionen im Schema sind vollstaendig vorhanden', () {
      expect(db.schemaVersion, 1);
      expect(db.mediaItemsTable.tableName, 'media_items');
      expect(db.bookmarksTable.tableName, 'bookmarks');
      expect(db.playbackHistoryTable.tableName, 'playback_history');
      expect(db.sleepPresetsTable.tableName, 'sleep_presets');

      // Primaerschluessel und Tabellen-Instanzen pruefen
      expect(db.mediaItemsTable, isNotNull);
      expect(db.bookmarksTable, isNotNull);
      expect(db.playbackHistoryTable, isNotNull);
      expect(db.sleepPresetsTable, isNotNull);
    });

    test('MediaItem CRUD-Operationen funktionieren asynchron und zuverlaessig', () async {
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

    test('Millisekunden-genaue Speicherung und Abruf der letzten Abspielposition', () async {
      const item = MediaItem(
        id: 'audio-prec',
        title: 'Precision Track',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/storage/track.mp3'),
      );
      await dao.insertMediaItem(item);

      // Exakte Millisekunden setzen: z. B. 123456 ms (2m 3s 456ms)
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

    test('Reaktive Streams (watch) emittieren Zustandsaenderungen live', () async {
      var emittedLists = <List<MediaItem>>[];
      final sub = dao.watchAllMediaItems().listen((list) {
        emittedLists.add(list);
      });

      // Erster Zustand
      await Future<void>.delayed(Duration.zero);
      expect(emittedLists.isNotEmpty, isTrue);

      // Neues Medium einfuegen
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

    test('Transaktionale Integritaet bei Batch-Updates (Batch-Upsert)', () async {
      final items = List.generate(
        10,
        (i) => MediaItem(
          id: 'batch-item-$i',
          title: 'Kapitel $i',
          type: MediaType.audiobook,
          source: AudioSourceRef.localFile(filePath: '/audio/$i.mp3'),
        ),
      );

      // Batch atomar einfuegen
      await dao.batchUpsertMediaItems(items);

      final all = await dao.getAllMediaItems();
      expect(all.length, 10);
      expect(all.map((m) => m.id), containsAll(['batch-item-0', 'batch-item-9']));
    });

    test('Transaktionaler Rollback bei Fehlschlag im Batch', () async {
      const item1 = MediaItem(
        id: 'safe-item-1',
        title: 'Sicher 1',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/1.mp3'),
      );
      await dao.insertMediaItem(item1);

      // Transaktion mit gewolltem Fehler
      expect(
        () async {
          await db.transaction(() async {
            await dao.insertMediaItem(
              const MediaItem(
                id: 'trans-item-2',
                title: 'Trans 2',
                type: MediaType.audiobook,
                source: AudioSourceRef.localFile(filePath: '/audio/2.mp3'),
              ),
            );
            // Kuenstlicher Abbruch
            throw Exception('Rollback erzwungen!');
          });
        },
        throwsException,
      );
    });

    test('Kaskadierende Loeschung: Bookmarks & History werden mit MediaItem geloescht', () async {
      const media = MediaItem(
        id: 'parent-media',
        title: 'Hoerbuch mit Lesezeichen',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/parent.m4b'),
      );
      await dao.insertMediaItem(media);

      // 2 Lesezeichen anlegen
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

      // Historie anlegen
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

      // MediaItem loeschen -> Kaskadierende Loeschung verifizieren
      await dao.deleteMediaItem('parent-media');

      expect(await dao.getMediaItemById('parent-media'), isNull);
      expect((await dao.getBookmarksForMedia('parent-media')).isEmpty, isTrue);
      expect((await dao.getPlaybackHistory('parent-media')).isEmpty, isTrue);
    });

    test('Fremdschluessel-Pruefung verhindert verwaiste Bookmarks und Historie', () async {
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

    test('SleepPresets CRUD und Sortierung nach Minuten', () async {
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
      // Sortiert nach Dauer: 15 Min vor 30 Min
      expect(presets.first.durationMinutes, 15);
      expect(presets.last.durationMinutes, 30);
      expect(presets.last.isDefault, isTrue);

      await dao.deleteSleepPreset('preset-15');
      expect((await dao.getSleepPresets()).length, 1);
    });
  });
}
