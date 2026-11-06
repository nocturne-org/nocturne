import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/repositories/media_repository.dart';
import 'package:nocturne/data/repositories/media_repository_impl.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/chapter.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/presentation/controllers/audiobook_player_controller.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/providers/repository_providers.dart';

class TestMockAudioPlayer implements AudioPlayerRepository {
  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  AudioPlaybackStatus status = AudioPlaybackStatus.idle;
  Duration position = Duration.zero;
  Duration? lastInitialPosition;

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
    lastInitialPosition = initialPosition;
    if (initialPosition != null) {
      position = initialPosition;
    }
    status = AudioPlaybackStatus.ready;
    _statusCtrl.add(status);
  }

  @override
  Future<void> play() async {
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
    status = AudioPlaybackStatus.idle;
    _statusCtrl.add(status);
  }

  @override
  Future<void> seek(Duration pos) async {
    position = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volCtrl.add(volume);
  }

  void emitPosition(Duration pos) {
    position = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  group('AudiobookPlayerController Tests (TICK-012)', () {
    late AppDatabase memoryDb;
    late MediaRepository mediaRepo;
    late TestMockAudioPlayer mockPlayer;
    late ProviderContainer container;

    setUp(() {
      memoryDb = AppDatabase.memory();
      mediaRepo = MediaRepositoryImpl(db: memoryDb);
      mockPlayer = TestMockAudioPlayer();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
          mediaRepositoryProvider.overrideWithValue(mediaRepo),
          audioPlayerRepositoryProvider.overrideWithValue(mockPlayer),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await mockPlayer.dispose();
      await memoryDb.close();
    });

    test('Wiederaufnahme an exakt der gespeicherten Position (Auto-Resume)', () async {
      const savedPos = PlaybackPosition(duration: Duration(milliseconds: 142500));
      const media = MediaItem(
        id: 'book-resume',
        title: 'Auto-Resume Hoerbuch',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/resume.m4b'),
        lastPosition: savedPos,
      );
      await mediaRepo.saveMedia(media);

      final controller = container.read(audiobookPlayerControllerProvider.notifier);
      await controller.loadAndPlay(media, autoResume: true);

      expect(mockPlayer.lastInitialPosition, savedPos.duration);
      expect(mockPlayer.position, savedPos.duration);
      expect(container.read(audiobookPlayerControllerProvider).position, savedPos);
    });

    test('Automatisches Setzen des Fortschrittslesezeichens alle 5 Sekunden', () async {
      const media = MediaItem(
        id: 'book-periodic',
        title: 'Periodischer Test',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/test.m4b'),
      );
      await mediaRepo.saveMedia(media);

      final controller = container.read(audiobookPlayerControllerProvider.notifier);
      await controller.loadAndPlay(media, autoResume: false);

      // Position um 5000 ms vorstellen
      mockPlayer.emitPosition(const Duration(milliseconds: 5500));
      await Future<void>.delayed(Duration.zero);

      final updated = await mediaRepo.getMediaById('book-periodic');
      expect(updated!.lastPosition.milliseconds, 5500);
    });

    test('Sofortiges Speichern des Lesezeichens beim Pausieren', () async {
      const media = MediaItem(
        id: 'book-pause',
        title: 'Pause Test',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/pause.m4b'),
      );
      await mediaRepo.saveMedia(media);

      final controller = container.read(audiobookPlayerControllerProvider.notifier);
      await controller.loadAndPlay(media, autoResume: false);

      // Auf 12 Sekunden springen
      await controller.seek(const Duration(seconds: 12));
      await controller.pause();

      final updated = await mediaRepo.getMediaById('book-pause');
      expect(updated!.lastPosition.duration.inSeconds, 12);
    });

    test('Kapitelliste ermoeglicht direktes Anspringen einzelner Abschnitte', () async {
      const chapters = [
        Chapter(
          id: 'c1',
          title: 'Kapitel 1',
          start: Duration.zero,
          end: Duration(minutes: 5),
          index: 0,
        ),
        Chapter(
          id: 'c2',
          title: 'Kapitel 2',
          start: Duration(minutes: 5),
          end: Duration(minutes: 12),
          index: 1,
        ),
      ];

      const media = MediaItem(
        id: 'book-chap',
        title: 'Kapitel Hoerbuch',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/chap.m4b'),
        chapters: chapters,
      );
      await mediaRepo.saveMedia(media);

      final controller = container.read(audiobookPlayerControllerProvider.notifier);
      await controller.loadAndPlay(media, autoResume: false);

      // Zu Kapitel 2 springen
      await controller.seekToChapter(1);

      final state = container.read(audiobookPlayerControllerProvider);
      expect(state.currentChapter?.title, 'Kapitel 2');
      expect(state.position.duration, const Duration(minutes: 5));
      expect(mockPlayer.position, const Duration(minutes: 5));
    });

    test('Nahtlose Wiedergabe von Multi-Track Hoerbuechern', () async {
      const track1 = MediaItem(
        id: 'track-1',
        title: 'Teil 1',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/t1.mp3'),
      );
      const track2 = MediaItem(
        id: 'track-2',
        title: 'Teil 2',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/t2.mp3'),
      );
      await mediaRepo.saveMedia(track1);
      await mediaRepo.saveMedia(track2);

      final controller = container.read(audiobookPlayerControllerProvider.notifier);
      await controller.loadMultiTrack([track1, track2], initialTrackIndex: 0);

      expect(container.read(audiobookPlayerControllerProvider).currentMedia?.id, 'track-1');

      // Naechsten Track aufrufen
      await controller.nextTrack();

      final state = container.read(audiobookPlayerControllerProvider);
      expect(state.currentMedia?.id, 'track-2');
      expect(state.currentTrackIndex, 1);
    });
  });
}
