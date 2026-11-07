import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';

void main() {
  group('SleepTimerState Domain Model Tests (TICK-V2-02)', () {
    test('Initial state properties are correct', () {
      const state = SleepTimerState.initial;

      expect(state.mode, SleepTimerMode.off);
      expect(state.status, SleepTimerStatus.inactive);
      expect(state.totalDuration, Duration.zero);
      expect(state.remainingDuration, Duration.zero);
      expect(state.volumeFactor, 1.0);
      expect(state.currentVolume, 1.0);
      expect(state.preset, SleepTimerPreset.m30);
      expect(state.gracePeriodRemaining, const Duration(seconds: 120));
      expect(state.isActive, false);
      expect(state.isCounting, false);
      expect(state.isFadingOut, false);
      expect(state.isGracePeriod, false);
      expect(state.isStopped, true);
      expect(state.progressFraction, 0.0);
      expect(state.formatRemaining(), '00:00');
    });

    test('Countdown state properties are correct', () {
      final state = const SleepTimerState(
        status: SleepTimerStatus.counting,
        totalDuration: Duration(minutes: 30),
        remainingDuration: Duration(minutes: 25),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.m30,
      );

      expect(state.mode, SleepTimerMode.countdown);
      expect(state.status, SleepTimerStatus.counting);
      expect(state.isActive, true);
      expect(state.isCounting, true);
      expect(state.isFadingOut, false);
      expect(state.isGracePeriod, false);
      expect(state.isStopped, false);
      expect(state.formatRemaining(), '25:00');
      expect(state.progressFraction, closeTo(5 / 30, 0.001));
    });

    test('FadeOut and GracePeriod states reflect accurate flags', () {
      final fadeState = const SleepTimerState(
        status: SleepTimerStatus.fadingOut,
        totalDuration: Duration(minutes: 15),
        remainingDuration: Duration(seconds: 45),
        volumeFactor: 0.5,
        preset: SleepTimerPreset.m15,
      );

      expect(fadeState.isActive, true);
      expect(fadeState.isCounting, false);
      expect(fadeState.isFadingOut, true);
      expect(fadeState.isGracePeriod, false);
      expect(fadeState.formatRemaining(), '00:45');

      final graceState = const SleepTimerState(
        status: SleepTimerStatus.gracePeriod,
        totalDuration: Duration(minutes: 15),
        remainingDuration: Duration.zero,
        volumeFactor: 0.0,
        preset: SleepTimerPreset.m15,
        gracePeriodRemaining: Duration(seconds: 80),
      );

      expect(graceState.isActive, true);
      expect(graceState.isGracePeriod, true);
      expect(graceState.isFadingOut, false);
      expect(graceState.gracePeriodRemaining, const Duration(seconds: 80));
    });

    test('ChapterEnd mode initializes correctly', () {
      final chapterState = const SleepTimerState(
        status: SleepTimerStatus.counting,
        totalDuration: Duration(minutes: 42),
        remainingDuration: Duration(minutes: 42),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.untilChapterEnd,
      );

      expect(chapterState.mode, SleepTimerMode.untilChapterEnd);
      expect(chapterState.preset, SleepTimerPreset.untilChapterEnd);
      expect(chapterState.isActive, true);
    });

    test('formatRemaining formats hours when duration exceeds 60 minutes', () {
      final state = const SleepTimerState(
        status: SleepTimerStatus.counting,
        totalDuration: Duration(hours: 1, minutes: 15, seconds: 30),
        remainingDuration: Duration(hours: 1, minutes: 15, seconds: 30),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.custom,
      );

      expect(state.formatRemaining(), '01:15:30');
    });

    test('copyWith handles backward compatibility fields', () {
      const initial = SleepTimerState.initial;

      final updated = initial.copyWith(
        isActive: true,
        remainingDuration: const Duration(minutes: 10),
        totalDuration: const Duration(minutes: 10),
        currentVolume: 0.8,
      );

      expect(updated.isActive, true);
      expect(updated.isCounting, true);
      expect(updated.mode, SleepTimerMode.countdown);
      expect(updated.volumeFactor, 0.8);
      expect(updated.currentVolume, 0.8);

      final fading = updated.copyWith(isFadingOut: true);
      expect(fading.isFadingOut, true);
      expect(fading.status, SleepTimerStatus.fadingOut);

      final grace = fading.copyWith(isGracePeriod: true);
      expect(grace.isGracePeriod, true);
      expect(grace.status, SleepTimerStatus.gracePeriod);

      final stopped = grace.copyWith(isActive: false);
      expect(stopped.isActive, false);
      expect(stopped.isStopped, true);
    });

    test('Equality and hashCode contract', () {
      final state1 = const SleepTimerState(
        mode: SleepTimerMode.countdown,
        status: SleepTimerStatus.counting,
        totalDuration: Duration(minutes: 15),
        remainingDuration: Duration(minutes: 10),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.m15,
      );

      final state2 = const SleepTimerState(
        mode: SleepTimerMode.countdown,
        status: SleepTimerStatus.counting,
        totalDuration: Duration(minutes: 15),
        remainingDuration: Duration(minutes: 10),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.m15,
      );

      final different = state1.copyWith(
        remainingDuration: const Duration(minutes: 9),
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1, isNot(equals(different)));
    });

    test('SleepTimerPreset properties', () {
      expect(SleepTimerPreset.m5.fixedDuration, const Duration(minutes: 5));
      expect(SleepTimerPreset.m10.fixedDuration, const Duration(minutes: 10));
      expect(SleepTimerPreset.m15.fixedDuration, const Duration(minutes: 15));
      expect(SleepTimerPreset.m30.fixedDuration, const Duration(minutes: 30));
      expect(SleepTimerPreset.m45.fixedDuration, const Duration(minutes: 45));
      expect(SleepTimerPreset.m60.fixedDuration, const Duration(minutes: 60));
      expect(SleepTimerPreset.untilChapterEnd.fixedDuration, isNull);
      expect(SleepTimerPreset.custom.fixedDuration, isNull);
      expect(SleepTimerPreset.off.fixedDuration, isNull);

      expect(SleepTimerPreset.m5.label, '5 min');
      expect(SleepTimerPreset.untilChapterEnd.label, 'End of chapter');
      expect(SleepTimerPreset.custom.label, 'Custom');
      expect(SleepTimerPreset.off.label, 'Off');
    });
  });
}
