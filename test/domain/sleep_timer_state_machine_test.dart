import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';
import 'package:nocturne/domain/usecases/sleep_timer_state_machine.dart';

void main() {
  group('SleepTimerStateMachine', () {
    late SleepTimerStateMachine stateMachine;

    setUp(() {
      stateMachine = SleepTimerStateMachine();
    });

    tearDown(() {
      stateMachine.dispose();
    });

    test('Initial state is inactive with full volume', () {
      expect(stateMachine.state.status, SleepTimerStatus.inactive);
      expect(stateMachine.state.volumeFactor, 1.0);
      expect(stateMachine.state.remainingDuration, Duration.zero);
      expect(stateMachine.state.isActive, isFalse);
    });

    test('start() with duration > 60s transitions to counting', () {
      stateMachine.start(
        duration: const Duration(minutes: 15),
        preset: SleepTimerPreset.m15,
        enableAutoTick: false,
      );

      expect(stateMachine.state.status, SleepTimerStatus.counting);
      expect(stateMachine.state.remainingDuration, const Duration(minutes: 15));
      expect(stateMachine.state.totalDuration, const Duration(minutes: 15));
      expect(stateMachine.state.volumeFactor, 1.0);
      expect(stateMachine.state.isActive, isTrue);
      expect(stateMachine.state.isCounting, isTrue);
    });

    test('start() with duration <= 60s transitions immediately to fadingOut', () {
      stateMachine.start(
        duration: const Duration(seconds: 30),
        enableAutoTick: false,
      );

      expect(stateMachine.state.status, SleepTimerStatus.fadingOut);
      expect(stateMachine.state.isFadingOut, isTrue);
      // Volume at 30s remaining: (30/60)^2 = 0.25
      expect(stateMachine.state.volumeFactor, closeTo(0.25, 0.001));
    });

    test('startWithPreset() configures correct fixed durations', () {
      stateMachine.startWithPreset(SleepTimerPreset.m30, enableAutoTick: false);
      expect(stateMachine.state.totalDuration, const Duration(minutes: 30));
      expect(stateMachine.state.preset, SleepTimerPreset.m30);

      stateMachine.startWithPreset(
        SleepTimerPreset.untilChapterEnd,
        chapterRemaining: const Duration(minutes: 12, seconds: 40),
        enableAutoTick: false,
      );
      expect(
        stateMachine.state.totalDuration,
        const Duration(minutes: 12, seconds: 40),
      );
      expect(stateMachine.state.preset, SleepTimerPreset.untilChapterEnd);
    });

    test('tick() decrements remainingDuration in counting phase', () {
      stateMachine.start(
        duration: const Duration(minutes: 10),
        enableAutoTick: false,
      );

      stateMachine.tick(const Duration(minutes: 2));

      expect(stateMachine.state.remainingDuration, const Duration(minutes: 8));
      expect(stateMachine.state.status, SleepTimerStatus.counting);
      expect(stateMachine.state.volumeFactor, 1.0);
    });

    test('Transitions to fadingOut when remainingDuration <= 60s', () {
      stateMachine.start(
        duration: const Duration(seconds: 90),
        enableAutoTick: false,
      );

      stateMachine.tick(const Duration(seconds: 30));

      expect(stateMachine.state.remainingDuration, const Duration(seconds: 60));
      expect(stateMachine.state.status, SleepTimerStatus.fadingOut);
      expect(stateMachine.state.volumeFactor, closeTo(1.0, 0.001));

      // Tick another 30 seconds -> 30s remaining
      stateMachine.tick(const Duration(seconds: 30));
      expect(stateMachine.state.remainingDuration, const Duration(seconds: 30));
      // Volume = (30/60)^2 = 0.25
      expect(stateMachine.state.volumeFactor, closeTo(0.25, 0.001));
    });

    test('Transitions to gracePeriod when fade-out expires (remaining <= 0s)', () {
      Duration? reportedOffset;
      stateMachine.onGracePeriodStarted = (offset) {
        reportedOffset = offset;
      };

      stateMachine.start(
        duration: const Duration(seconds: 60),
        enableAutoTick: false,
      );

      stateMachine.tick(const Duration(seconds: 60));

      expect(stateMachine.state.status, SleepTimerStatus.gracePeriod);
      expect(stateMachine.state.isGracePeriod, isTrue);
      expect(stateMachine.state.volumeFactor, 0.0);
      expect(stateMachine.state.remainingDuration, const Duration(seconds: 120));
      expect(reportedOffset, const Duration(seconds: 105));
    });

    test('Grace period ticks down and transitions to stopped after 120s', () {
      var stoppedReported = false;
      stateMachine.onTimerStopped = () {
        stoppedReported = true;
      };

      stateMachine.start(
        duration: const Duration(seconds: 10),
        enableAutoTick: false,
      );

      // Reaches gracePeriod
      stateMachine.tick(const Duration(seconds: 10));
      expect(stateMachine.state.status, SleepTimerStatus.gracePeriod);

      // Advance 60s into grace period
      stateMachine.tick(const Duration(seconds: 60));
      expect(stateMachine.state.remainingDuration, const Duration(seconds: 60));
      expect(stateMachine.state.status, SleepTimerStatus.gracePeriod);
      expect(stoppedReported, isFalse);

      // Advance remaining 60s -> total 120s grace period expired
      stateMachine.tick(const Duration(seconds: 60));
      expect(stateMachine.state.status, SleepTimerStatus.stopped);
      expect(stateMachine.state.isStopped, isTrue);
      expect(stateMachine.state.isActive, isFalse);
      expect(stoppedReported, isTrue);
    });

    test('Shake detected in counting phase adds extend interval', () {
      stateMachine.start(
        duration: const Duration(minutes: 10),
        extendInterval: const Duration(minutes: 15),
        enableAutoTick: false,
      );

      final handled = stateMachine.onShakeDetected();

      expect(handled, isTrue);
      expect(stateMachine.state.status, SleepTimerStatus.counting);
      expect(stateMachine.state.remainingDuration, const Duration(minutes: 25));
      expect(stateMachine.state.totalDuration, const Duration(minutes: 25));
    });

    test('Shake detected in fadingOut resets volume to 1.0 and resumes counting', () {
      double? updatedVolume;
      stateMachine.onVolumeChanged = (vol) {
        updatedVolume = vol;
      };

      stateMachine.start(
        duration: const Duration(seconds: 30),
        extendInterval: const Duration(minutes: 15),
        enableAutoTick: false,
      );

      expect(stateMachine.state.status, SleepTimerStatus.fadingOut);

      final handled = stateMachine.onShakeDetected();

      expect(handled, isTrue);
      expect(stateMachine.state.status, SleepTimerStatus.counting);
      expect(stateMachine.state.volumeFactor, 1.0);
      expect(updatedVolume, 1.0);
      expect(
        stateMachine.state.remainingDuration,
        const Duration(minutes: 15, seconds: 30),
      );
    });

    test('Shake detected in gracePeriod wakes engine, resets volume and restarts counting', () {
      double? updatedVolume;
      Duration? extendedRemaining;
      stateMachine.onVolumeChanged = (vol) => updatedVolume = vol;
      stateMachine.onExtended = (rem) => extendedRemaining = rem;

      stateMachine.start(
        duration: const Duration(seconds: 5),
        extendInterval: const Duration(minutes: 15),
        enableAutoTick: false,
      );

      // Enter grace period
      stateMachine.tick(const Duration(seconds: 5));
      expect(stateMachine.state.status, SleepTimerStatus.gracePeriod);

      final handled = stateMachine.onShakeDetected();

      expect(handled, isTrue);
      expect(stateMachine.state.status, SleepTimerStatus.counting);
      expect(stateMachine.state.volumeFactor, 1.0);
      expect(updatedVolume, 1.0);
      expect(stateMachine.state.remainingDuration, const Duration(minutes: 15));
      expect(extendedRemaining, const Duration(minutes: 15));
    });

    test('Shake detected when inactive or stopped does nothing', () {
      expect(stateMachine.onShakeDetected(), isFalse);

      stateMachine.start(
        duration: const Duration(seconds: 1),
        enableAutoTick: false,
      );
      stateMachine.tick(const Duration(seconds: 1)); // -> grace
      stateMachine.tick(const Duration(seconds: 120)); // -> stopped
      expect(stateMachine.state.status, SleepTimerStatus.stopped);

      expect(stateMachine.onShakeDetected(), isFalse);
    });

    test('cancel() resets to inactive with full volume', () {
      stateMachine.start(
        duration: const Duration(minutes: 30),
        enableAutoTick: false,
      );

      stateMachine.cancel();

      expect(stateMachine.state.status, SleepTimerStatus.inactive);
      expect(stateMachine.state.remainingDuration, Duration.zero);
      expect(stateMachine.state.volumeFactor, 1.0);
    });

    test('stateStream emits on state changes', () async {
      final states = <SleepTimerStatus>[];
      final sub = stateMachine.stateStream.listen((s) {
        states.add(s.status);
      });

      stateMachine.start(
        duration: const Duration(seconds: 70),
        enableAutoTick: false,
      );
      stateMachine.tick(const Duration(seconds: 20)); // -> fadingOut (50s left)
      stateMachine.tick(const Duration(seconds: 50)); // -> gracePeriod
      stateMachine.tick(const Duration(seconds: 120)); // -> stopped

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        SleepTimerStatus.counting,
        SleepTimerStatus.fadingOut,
        SleepTimerStatus.gracePeriod,
        SleepTimerStatus.stopped,
      ]);
    });
  });
}
