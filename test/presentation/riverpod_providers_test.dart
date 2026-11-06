import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/providers/database_provider.dart';
import 'package:nocturne/presentation/providers/media_providers.dart';
import 'package:nocturne/presentation/providers/repository_providers.dart';
import 'package:nocturne/presentation/providers/timer_providers.dart';

class MockAudioPlayerRepository implements AudioPlayerRepository {
  AudioPlaybackStatus currentStatus = AudioPlaybackStatus.idle;
  double currentVolume = 1.0;
  Duration currentPosition = Duration.zero;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream =>
      Stream.value(currentStatus);

  @override
  Stream<Duration> get positionStream => Stream.value(currentPosition);

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(minutes: 60));

  @override
  Stream<double> get volumeStream => Stream.value(currentVolume);

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    currentStatus = AudioPlaybackStatus.ready;
    if (initialPosition != null) currentPosition = initialPosition;
  }

  @override
  Future<void> play() async {
    currentStatus = AudioPlaybackStatus.playing;
  }

  @override
  Future<void> pause() async {
    currentStatus = AudioPlaybackStatus.paused;
  }

  @override
  Future<void> stop() async {
    currentStatus = AudioPlaybackStatus.idle;
    currentPosition = Duration.zero;
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Riverpod DI-Graph & State-Management Tests (TICK-004)', () {
    late AppDatabase memoryDb;
    late MockAudioPlayerRepository mockAudioPlayer;
    late ProviderContainer container;

    setUp(() {
      memoryDb = AppDatabase.memory();
      mockAudioPlayer = MockAudioPlayerRepository();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
          audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayer),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await memoryDb.close();
    });

    test('Provider-Hierarchie loest Repositories und Database sauber auf', () {
      final db = container.read(databaseProvider);
      expect(db, memoryDb);

      final repo = container.read(mediaRepositoryProvider);
      expect(repo, isNotNull);

      final audio = container.read(audioPlayerRepositoryProvider);
      expect(audio, mockAudioPlayer);
    });

    test('MediaListNotifier behandelt asynchrone Zustaende (AsyncValue)', () async {
      final initialAsync = container.read(mediaListNotifierProvider);
      expect(initialAsync, isA<AsyncLoading<List<MediaItem>>>());

      // Warten bis der initiale Ladezustand fertig ist
      final initialList = await container.read(mediaListNotifierProvider.future);
      expect(initialList, isEmpty);

      // Medium ueber Notifier importieren
      const testItem = MediaItem(
        id: 'book-42',
        title: 'Per Anhalter durch die Galaxis',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/audio/douglas.m4b'),
      );
      await container.read(mediaListNotifierProvider.notifier).batchImportMedia([testItem]);

      final updatedList = await container.read(mediaListNotifierProvider.future);
      expect(updatedList.length, 1);
      expect(updatedList.first.title, 'Per Anhalter durch die Galaxis');

      // Medium loeschen
      await container.read(mediaListNotifierProvider.notifier).deleteMedia('book-42');
      final afterDelete = await container.read(mediaListNotifierProvider.future);
      expect(afterDelete, isEmpty);
    });

    test('ActiveMediaNotifier waehlt Medien aus und aktualisiert Position', () async {
      final repo = container.read(mediaRepositoryProvider);
      const item = MediaItem(
        id: 'active-1',
        title: 'Aktives Hoerbuch',
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: '/storage/1.m4b'),
      );
      await repo.saveMedia(item);

      final notifier = container.read(activeMediaNotifierProvider.notifier);
      await notifier.selectMedia('active-1');

      final active = container.read(activeMediaNotifierProvider).value;
      expect(active, isNotNull);
      expect(active!.id, 'active-1');

      // Position aktualisieren (exakte Millisekunden)
      const newPos = PlaybackPosition(duration: Duration(milliseconds: 98765));
      await notifier.updatePosition(newPos);

      final afterPosUpdate = container.read(activeMediaNotifierProvider).value;
      expect(afterPosUpdate!.lastPosition.milliseconds, 98765);
    });

    test('TimerController verwaltet Countdown, Fade-Out und Shake-Grace-Period', () {
      final timer = container.read(timerControllerProvider.notifier);

      // 1. Timer mit 30 Minuten starten
      timer.startTimer(const Duration(minutes: 30));
      var state = container.read(timerControllerProvider);
      expect(state.isActive, isTrue);
      expect(state.remainingDuration.inMinutes, 30);
      expect(state.currentVolume, 1.0);
      expect(state.isFadingOut, isFalse);
      expect(state.isGracePeriod, isFalse);

      // 2. Zeitschritt: herunterzaehlen bis auf 30 Sekunden Restzeit
      timer.tick(const Duration(minutes: 29, seconds: 30));
      state = container.read(timerControllerProvider);
      expect(state.isFadingOut, isTrue);
      expect(state.remainingDuration.inSeconds, 30);
      // Quadratisch-logarithmischer Lautstaerke-Fade: (30/60)^2 = 0.25
      expect(state.currentVolume, closeTo(0.25, 0.01));

      // 3. Zeitschritt: Restzeit laeuft ab (30s) -> Grace-Period beginnt
      timer.tick(const Duration(seconds: 30));
      state = container.read(timerControllerProvider);
      expect(state.isGracePeriod, isTrue);
      expect(state.currentVolume, 0.0);
      expect(state.gracePeriodRemaining.inSeconds, 120);

      // 4. Schütteln in der Grace-Period verlaengert um 15 Minuten und stellt Lautstaerke wieder her
      timer.handleShake();
      state = container.read(timerControllerProvider);
      expect(state.isActive, isTrue);
      expect(state.isGracePeriod, isFalse);
      expect(state.isFadingOut, isFalse);
      expect(state.currentVolume, 1.0);
      expect(state.remainingDuration.inMinutes, 15);

      // 5. Cancel stoppt den Timer
      timer.cancelTimer();
      state = container.read(timerControllerProvider);
      expect(state.isActive, isFalse);
    });
  });
}
