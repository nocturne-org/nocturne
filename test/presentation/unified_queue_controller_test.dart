import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/repositories/media_repository_impl.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/presentation/controllers/unified_queue_controller.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/providers/queue_providers.dart';
import 'package:nocturne/presentation/providers/repository_providers.dart';
import 'package:nocturne/presentation/state/unified_queue_state.dart';

class MockAudioPlayerForQueue implements AudioPlayerRepository {
  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  AudioPlaybackStatus status = AudioPlaybackStatus.idle;
  AudioSourceRef? currentSource;
  int playCallCount = 0;
  int stopCallCount = 0;
  int seekCallCount = 0;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    currentSource = source;
    status = AudioPlaybackStatus.ready;
    _statusCtrl.add(status);
  }

  @override
  Future<void> play() async {
    playCallCount++;
    status = AudioPlaybackStatus.playing;
    _statusCtrl.add(status);
  }

  @override
  Future<void> pause() async {
    status = AudioPlaybackStatus.paused;
    _statusCtrl.add(status);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    status = AudioPlaybackStatus.idle;
    _statusCtrl.add(status);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCallCount++;
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volCtrl.add(volume.clamp(0.0, 1.0));
  }

  void simulateTrackCompleted() {
    status = AudioPlaybackStatus.completed;
    _statusCtrl.add(status);
  }

  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  group('UnifiedQueueController Tests', () {
    late AppDatabase db;
    late MediaRepositoryImpl mediaRepo;
    late MockAudioPlayerForQueue player;
    late ProviderContainer container;

    // Lokales Hoerbuch
    final audiobookItem = MediaItem(
      id: 'item_audiobook_1',
      title: 'Momo',
      author: 'Michael Ende',
      duration: const Duration(milliseconds: 14400000),
      source: AudioSourceRef.localFile(filePath: '/storage/momo.m4b'),
    );

    // Podcast-Folge
    final podcastItem = MediaItem(
      id: 'item_podcast_2',
      title: 'Einschlafen mit Wikipedia Folge 101',
      author: 'Wikipedia Podcast',
      duration: const Duration(milliseconds: 2700000),
      source: AudioSourceRef.remoteStream(streamUrl: 'https://podcast.de/ep101.mp3'),
      extraMetadata: const {'podcast_title': 'Einschlafen mit Wikipedia'},
    );

    // YouTube Audio-Track
    final youtubeItem = MediaItem(
      id: 'item_youtube_3',
      title: 'Deep Sleep Binaural Beats 432Hz',
      author: 'Ambient Night',
      duration: const Duration(milliseconds: 28800000),
      source: AudioSourceRef.remoteStream(streamUrl: 'https://rr1.googlevideo.com/audio_128k'),
    );

    setUp(() async {
      db = AppDatabase.memory();
      mediaRepo = MediaRepositoryImpl(db: db);
      player = MockAudioPlayerForQueue();

      await mediaRepo.saveMedia(audiobookItem);
      await mediaRepo.saveMedia(podcastItem);
      await mediaRepo.saveMedia(youtubeItem);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaRepositoryProvider.overrideWithValue(mediaRepo),
          audioPlayerRepositoryProvider.overrideWithValue(player),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await player.dispose();
      await db.close();
    });

    test('addItem fuegt Medientyp hinzu und startet Wiedergabe wenn leer', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItem(audiobookItem);

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.totalTracks, 1);
      expect(state.currentIndex, 0);
      expect(state.currentItem?.id, audiobookItem.id);
      expect(player.currentSource, audiobookItem.source);
      expect(player.playCallCount, 1);
    });

    test('addItems akzeptiert Kombination aus Audiobuch, Podcast und YouTube', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, podcastItem, youtubeItem]);

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.totalTracks, 3);
      expect(state.items[0].id, audiobookItem.id);
      expect(state.items[1].id, podcastItem.id);
      expect(state.items[2].id, youtubeItem.id);
      expect(state.totalDurationMs,
          (audiobookItem.durationMs ?? 0) + (podcastItem.durationMs ?? 0) + (youtubeItem.durationMs ?? 0));

      // Persistenz in Drift pruefen
      final persistedQueue = await mediaRepo.loadPlaybackQueue();
      expect(persistedQueue, [audiobookItem.id, podcastItem.id, youtubeItem.id]);
    });

    test('insertNext platziert Titel direkt hinter dem aktuellen Index', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, youtubeItem]);
      // Aktuell spielt audiobookItem an Index 0

      await controller.insertNext(podcastItem);

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.totalTracks, 3);
      expect(state.items[0].id, audiobookItem.id);
      expect(state.items[1].id, podcastItem.id); // Eingefuegt an Index 1
      expect(state.items[2].id, youtubeItem.id);
    });

    test('reorder aendert Reihenfolge und passt currentIndex korrekt an', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, podcastItem, youtubeItem]);
      expect(container.read(unifiedQueueControllerProvider).currentIndex, 0);

      // Verschiebe Index 0 nach Index 2 (ReorderableListView Reorder-Logik)
      await controller.reorder(0, 3);

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.items[0].id, podcastItem.id);
      expect(state.items[1].id, youtubeItem.id);
      expect(state.items[2].id, audiobookItem.id);
      expect(state.currentIndex, 2); // Ursprungstrack bleibt ausgewaehlt
    });

    test('removeItem entfernt Titel und passt Warteschlange an', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, podcastItem, youtubeItem]);

      // Entferne mittleren Titel (podcastItem an Index 1)
      await controller.removeItem(1);

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.totalTracks, 2);
      expect(state.items[0].id, audiobookItem.id);
      expect(state.items[1].id, youtubeItem.id);

      final persistedQueue = await mediaRepo.loadPlaybackQueue();
      expect(persistedQueue, [audiobookItem.id, youtubeItem.id]);
    });

    test('Automatischer unterbrechungsfreier Uebergang zum naechsten Track', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, podcastItem]);
      expect(container.read(unifiedQueueControllerProvider).currentIndex, 0);

      // Simuliere Ende des ersten Titels
      player.simulateTrackCompleted();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.currentItem?.id, podcastItem.id);
      expect(player.currentSource, podcastItem.source);
    });

    test('QueueRepeatMode.single wiederholt denselben Track von vorn', () async {
      final controller = container.read(unifiedQueueControllerProvider.notifier);

      await controller.addItems([audiobookItem, podcastItem]);
      controller.setRepeatMode(QueueRepeatMode.single);

      player.simulateTrackCompleted();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(unifiedQueueControllerProvider);
      expect(state.currentIndex, 0);
      expect(player.seekCallCount, 1);
    });

    test('loadPersistedQueue stellt gespeicherte Warteschlange nach Neustart wieder her', () async {
      // Manuell im Repo speichern
      await mediaRepo.savePlaybackQueue(
        [podcastItem.id, youtubeItem.id],
        currentIndex: 1,
      );

      final freshContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaRepositoryProvider.overrideWithValue(mediaRepo),
          audioPlayerRepositoryProvider.overrideWithValue(player),
        ],
      );

      final freshController = freshContainer.read(unifiedQueueControllerProvider.notifier);
      await freshController.loadPersistedQueue();

      final state = freshContainer.read(unifiedQueueControllerProvider);
      expect(state.totalTracks, 2);
      expect(state.items[0].id, podcastItem.id);
      expect(state.items[1].id, youtubeItem.id);
      expect(state.currentIndex, 1);

      freshContainer.dispose();
    });
  });
}
