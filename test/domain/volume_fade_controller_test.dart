import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/sleep_timer_state_machine.dart';
import 'package:nocturne/domain/usecases/volume_fade_controller.dart';

/// Test-Fake fuer das [AudioPlayerRepository] zur Ueberpruefung der Lautstaerkeeinstellungen.
class FakeAudioPlayerRepository implements AudioPlayerRepository {
  final List<double> recordedVolumes = [];
  double _volume = 1.0;
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;

  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  double get volume => _volume;
  AudioPlaybackStatus get status => _status;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    recordedVolumes.add(_volume);
    _volCtrl.add(_volume);
  }

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    _status = AudioPlaybackStatus.ready;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> play() async {
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> pause() async {
    _status = AudioPlaybackStatus.paused;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> stop() async {
    _status = AudioPlaybackStatus.idle;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  group('VolumeFadeController Math & Curve Tests (TICK-014)', () {
    test('calculateFactor returns exact quadratic values at key milestones', () {
      // 60s rest = 100%
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: 60)),
        closeTo(1.0, 0.0001),
      );

      // 45s rest: (45/60)^2 = 0.75^2 = 0.5625
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: 45)),
        closeTo(0.5625, 0.0001),
      );

      // 30s rest: (30/60)^2 = 0.5^2 = 0.25
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: 30)),
        closeTo(0.25, 0.0001),
      );

      // 15s rest: (15/60)^2 = 0.25^2 = 0.0625
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: 15)),
        closeTo(0.0625, 0.0001),
      );

      // 0s rest = 0%
      expect(
        VolumeFadeController.calculateFactor(Duration.zero),
        closeTo(0.0, 0.0001),
      );
    });

    test('calculateFactor clamps cleanly outside boundaries', () {
      expect(
        VolumeFadeController.calculateFactor(const Duration(minutes: 5)),
        1.0,
      );
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: -10)),
        0.0,
      );
    });

    test('generateRampSteps produces monotonic sequence without clicks', () {
      final steps = VolumeFadeController.generateRampSteps(
        fadeDuration: const Duration(seconds: 60),
        stepInterval: const Duration(milliseconds: 100),
        volumeStart: 0.8,
      );

      // 60s at 100ms interval = 601 steps
      expect(steps.length, 601);
      expect(steps.first, closeTo(0.8, 0.001));
      expect(steps.last, closeTo(0.0, 0.001));

      // Monotoniefall pruefen & maximale Schrittgroesse limitieren
      for (var i = 0; i < steps.length - 1; i++) {
        final current = steps[i];
        final next = steps[i + 1];

        // Monoton fallend
        expect(current >= next, isTrue, reason: 'Step $i ($current) < next ($next)');

        // Keine akustischen Spruenge (max delta < 0.02 pro 100ms)
        final delta = current - next;
        expect(
          delta,
          lessThanOrEqualTo(0.02),
          reason: 'Delta between step $i and ${i + 1} exceeds 0.02 ($delta)',
        );
      }
    });
  });

  group('VolumeFadeController Audio Engine Integration (TICK-014)', () {
    late FakeAudioPlayerRepository fakeRepo;
    late VolumeFadeController fader;

    setUp(() {
      fakeRepo = FakeAudioPlayerRepository();
      fader = VolumeFadeController(
        playerRepository: fakeRepo,
        initialVolume: 0.8,
      );
    });

    tearDown(() async {
      await fader.dispose();
      await fakeRepo.dispose();
    });

    test('updateForRemaining scales volume based on initial user volume', () async {
      // 30s remaining -> factor = 0.25 -> 0.8 * 0.25 = 0.2
      await fader.updateForRemaining(const Duration(seconds: 30));

      expect(fader.currentFactor, closeTo(0.25, 0.001));
      expect(fader.effectiveVolume, closeTo(0.2, 0.001));
      expect(fakeRepo.volume, closeTo(0.2, 0.001));
    });

    test('restoreVolumeInstant resets volume immediately to 100% of volumeStart', () async {
      await fader.updateForRemaining(const Duration(seconds: 15));
      expect(fakeRepo.volume, closeTo(0.8 * 0.0625, 0.001));

      await fader.restoreVolumeInstant();

      expect(fader.currentFactor, 1.0);
      expect(fader.effectiveVolume, 0.8);
      expect(fakeRepo.volume, 0.8);
    });

    test('muteInstant sets volume immediately to 0.0', () async {
      await fader.muteInstant();

      expect(fader.currentFactor, 0.0);
      expect(fader.effectiveVolume, 0.0);
      expect(fakeRepo.volume, 0.0);
    });

    test('attachStateMachine coordinates automatic fade-out and shake restoration', () async {
      final stateMachine = SleepTimerStateMachine();
      fader.attachStateMachine(stateMachine);

      // Start timer with 90 seconds
      stateMachine.start(
        duration: const Duration(seconds: 90),
        enableAutoTick: false,
      );

      // At 90s (counting), volume stays 100%
      expect(fader.currentFactor, 1.0);

      // Advance by 30s -> exactly 60s remaining -> enters fadingOut
      stateMachine.tick(const Duration(seconds: 30));
      expect(stateMachine.state.status, SleepTimerStatus.fadingOut);
      await Future<void>.delayed(Duration.zero);
      expect(fader.currentFactor, closeTo(1.0, 0.001));

      // Advance to 30s remaining
      stateMachine.tick(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(fader.currentFactor, closeTo(0.25, 0.001));
      expect(fakeRepo.volume, closeTo(0.8 * 0.25, 0.001));

      // Shake detected during fade-out: volume must immediately jump back to 100%
      final handled = stateMachine.onShakeDetected();
      expect(handled, isTrue);
      expect(stateMachine.state.status, SleepTimerStatus.counting);
      await Future<void>.delayed(Duration.zero);
      expect(fader.currentFactor, 1.0);
      expect(fakeRepo.volume, 0.8);

      stateMachine.dispose();
    });

    test('attachStateMachine mutes upon gracePeriod and stopped states', () async {
      final stateMachine = SleepTimerStateMachine();
      fader.attachStateMachine(stateMachine);

      stateMachine.start(
        duration: const Duration(seconds: 10),
        enableAutoTick: false,
      );

      // Expire into gracePeriod
      stateMachine.tick(const Duration(seconds: 10));
      expect(stateMachine.state.status, SleepTimerStatus.gracePeriod);
      await Future<void>.delayed(Duration.zero);

      expect(fader.currentFactor, 0.0);
      expect(fakeRepo.volume, 0.0);

      stateMachine.dispose();
    });
  });
}
