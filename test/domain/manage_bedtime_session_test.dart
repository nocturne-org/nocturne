import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/manage_bedtime_session.dart';

class MockAudioPlayerRepository implements AudioPlayerRepository {
  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  AudioPlaybackStatus currentStatus = AudioPlaybackStatus.idle;
  Duration currentPosition = Duration.zero;
  Duration? lastSoughtPosition;
  double currentVolume = 1.0;
  bool isPlaying = false;
  bool isPaused = false;
  bool isStopped = false;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  void emitPosition(Duration pos) {
    currentPosition = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    isPaused = false;
    isStopped = false;
    currentStatus = AudioPlaybackStatus.playing;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    isPaused = true;
    currentStatus = AudioPlaybackStatus.paused;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    isPaused = false;
    isStopped = true;
    currentPosition = Duration.zero;
    currentStatus = AudioPlaybackStatus.idle;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSoughtPosition = position;
    currentPosition = position;
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume.clamp(0.0, 1.0);
    _volCtrl.add(currentVolume);
  }

  @override
  Future<void> setSource(AudioSourceRef source,
      {Duration? initialPosition}) async {
    currentStatus = AudioPlaybackStatus.ready;
    _statusCtrl.add(currentStatus);
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
  group('ManageBedtimeSession Tests (TICK-015)', () {
    late MockAudioPlayerRepository mockAudio;
    late ManageBedtimeSession session;
    final savedBookmarks = <Bookmark>[];
    final wakeLockEvents = <bool>[];
    final sensorEvents = <bool>[];

    setUp(() {
      savedBookmarks.clear();
      wakeLockEvents.clear();
      sensorEvents.clear();

      mockAudio = MockAudioPlayerRepository();
      session = ManageBedtimeSession(
        audioPlayer: mockAudio,
        onBookmarkSaved: (b) async => savedBookmarks.add(b),
        onWakeLockChanged: (enabled) async => wakeLockEvents.add(enabled),
        onSensorActiveChanged: (enabled) async => sensorEvents.add(enabled),
      );
    });

    tearDown(() async {
      await session.dispose();
      await mockAudio.dispose();
    });

    test('startSession activates WakeLock and Sensor', () async {
      await session.startSession(
        mediaItemId: 'book-123',
        timerDuration: const Duration(minutes: 30),
        enableAutoTick: false,
      );

      expect(session.activeMediaItemId, 'book-123');
      expect(session.timerState.status, SleepTimerStatus.counting);
      expect(wakeLockEvents.last, isTrue);
      expect(sensorEvents.last, isTrue);
    });

    test(
        'Entering GracePeriod sets bookmark at (fade_start - 45s) and pauses audio',
        () async {
      await session.startSession(
        mediaItemId: 'audiobook-42',
        timerDuration: const Duration(seconds: 90),
        enableAutoTick: false,
      );

      // Track playback position at 10 minutes (600s)
      mockAudio.emitPosition(const Duration(seconds: 600));

      // Advance by 30 seconds -> exactly 60s remaining -> enters fadingOut
      session.tick(const Duration(seconds: 30));
      expect(session.timerState.status, SleepTimerStatus.fadingOut);

      // Audio keeps playing forward slightly during the fade-out
      mockAudio.emitPosition(const Duration(seconds: 630));

      // Advance remaining 60 seconds -> rest = 0s -> enters gracePeriod
      session.tick(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);

      expect(session.timerState.status, SleepTimerStatus.gracePeriod);

      // 1. Audio must be paused
      expect(mockAudio.isPaused, isTrue);

      // 2. Bookmark must be saved:
      // Fade start was at 600s. Rewind offset = 45s -> Bookmark position = 600s - 45s = 555s
      expect(savedBookmarks.length, 1);
      final bookmark = savedBookmarks.first;
      expect(bookmark.mediaItemId, 'audiobook-42');
      expect(bookmark.position.duration, const Duration(seconds: 555));
      expect(bookmark.label, contains('Auto-Rewind'));

      // 3. Audio seeked to the bookmark position for seamless continuation
      expect(mockAudio.lastSoughtPosition, const Duration(seconds: 555));

      // 4. WakeLock and Sensor remain active during GracePeriod
      expect(wakeLockEvents.last, isTrue);
      expect(sensorEvents.last, isTrue);
    });

    test(
        'Shake during GracePeriod reactivates playback and resumes counting with 15m',
        () async {
      await session.startSession(
        mediaItemId: 'audiobook-42',
        timerDuration: const Duration(seconds: 10),
        extendInterval: const Duration(minutes: 15),
        enableAutoTick: false,
      );

      mockAudio.emitPosition(const Duration(minutes: 5));

      // Reaches gracePeriod
      session.tick(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);
      expect(session.timerState.status, SleepTimerStatus.gracePeriod);
      expect(mockAudio.isPaused, isTrue);

      // Sleeper shakes device during grace period
      final handled = await session.handleShake();

      expect(handled, isTrue);
      // Audio playback resumed!
      expect(mockAudio.isPlaying, isTrue);
      // Status back to counting with 15 minutes
      expect(session.timerState.status, SleepTimerStatus.counting);
      expect(session.timerState.remainingDuration, const Duration(minutes: 15));
    });

    test(
        'GracePeriod expiration without shake stops audio and releases WakeLock and Sensor',
        () async {
      await session.startSession(
        mediaItemId: 'audiobook-42',
        timerDuration: const Duration(seconds: 5),
        enableAutoTick: false,
      );

      // Transition to gracePeriod
      session.tick(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(session.timerState.status, SleepTimerStatus.gracePeriod);

      // Tick 120s Grace Period down to 0
      session.tick(const Duration(seconds: 120));
      await Future<void>.delayed(Duration.zero);

      // Final state: stopped
      expect(session.timerState.status, SleepTimerStatus.stopped);
      // Audio completely stopped
      expect(mockAudio.isStopped, isTrue);
      // WakeLock and Sensor released
      expect(wakeLockEvents.last, isFalse);
      expect(sensorEvents.last, isFalse);
    });

    test('Shake during fadingOut restores 100% volume and extends session',
        () async {
      await session.startSession(
        mediaItemId: 'audiobook-42',
        timerDuration: const Duration(seconds: 40),
        userVolume: 0.9,
        enableAutoTick: false,
      );

      expect(session.timerState.status, SleepTimerStatus.fadingOut);

      // Sleeper moves or shakes device while audio is fading
      final handled = await session.handleShake();

      expect(handled, isTrue);
      expect(session.timerState.status, SleepTimerStatus.counting);
      // Volume restored
      expect(mockAudio.currentVolume, closeTo(0.9, 0.001));
    });
  });
}
