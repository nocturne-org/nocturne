import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/sleep_timer_state.dart';

/// State-Notifier fuer den Bedtime Sleep-Timer gemaess Nocturne-Spezifikation.
/// Verwaltet Countdown, Lautstaerke-Fade-Out (60s) und Shake-Grace-Period (120s).
class TimerController extends Notifier<SleepTimerState> {
  @override
  SleepTimerState build() {
    return SleepTimerState.initial;
  }

  /// Startet den Sleep-Timer mit einer vorgegebenen Gesamtdauer.
  void startTimer(Duration duration) {
    state = SleepTimerState(
      isActive: true,
      remainingDuration: duration,
      totalDuration: duration,
      isFadingOut: duration.inSeconds <= 60,
      isGracePeriod: false,
      currentVolume: 1.0,
      gracePeriodRemaining: const Duration(seconds: 120),
    );
  }

  /// Verlaengert den Timer um 15 Minuten und setzt die Lautstaerke wieder auf 100%.
  void add15Minutes() {
    const extension = Duration(minutes: 15);
    if (!state.isActive && !state.isGracePeriod) {
      startTimer(extension);
      return;
    }

    final newRemaining = state.remainingDuration + extension;
    final newTotal = state.totalDuration + extension;

    state = state.copyWith(
      isActive: true,
      remainingDuration: newRemaining,
      totalDuration: newTotal,
      isFadingOut: false,
      isGracePeriod: false,
      currentVolume: 1.0,
      gracePeriodRemaining: const Duration(seconds: 120),
    );
  }

  /// Reagiert auf ein erkanntes Schüttel-Event (Shake Detection).
  /// Verlaengert bei Fade-Out oder innerhalb der Grace-Period um 15 Minuten.
  void handleShake() {
    if (state.isFadingOut || state.isGracePeriod) {
      add15Minutes();
    }
  }

  /// Berechnet einen Zeitschritt des Countdowns (z. B. jede Sekunde).
  void tick(Duration elapsed) {
    if (!state.isActive) return;

    if (!state.isGracePeriod) {
      final nextRemaining = state.remainingDuration - elapsed;

      if (nextRemaining > Duration.zero) {
        final inSeconds = nextRemaining.inSeconds;
        final isFading = inSeconds <= 60;
        var volume = 1.0;

        if (isFading) {
          // Quadratisch-logarithmischer Lautstaerke-Fade: (t / 60)^2
          final factor = inSeconds / 60.0;
          volume = max(0.0, min(1.0, factor * factor));
        }

        state = state.copyWith(
          remainingDuration: nextRemaining,
          isFadingOut: isFading,
          currentVolume: volume,
        );
      } else {
        // Countdown abgelaufen -> Wechsel in die 120s Grace-Period
        state = state.copyWith(
          remainingDuration: Duration.zero,
          isFadingOut: false,
          isGracePeriod: true,
          currentVolume: 0.0,
          gracePeriodRemaining: const Duration(seconds: 120),
        );
      }
    } else {
      // In Grace-Period herunterzaehlen
      final nextGrace = state.gracePeriodRemaining - elapsed;
      if (nextGrace > Duration.zero) {
        state = state.copyWith(gracePeriodRemaining: nextGrace);
      } else {
        // Grace-Period endgueltig abgelaufen -> Timer stoppt
        cancelTimer();
      }
    }
  }

  /// Bricht den aktiven Sleep-Timer ab und setzt den Zustand zurueck.
  void cancelTimer() {
    state = SleepTimerState.initial;
  }
}

/// Provider fuer den [TimerController].
final timerControllerProvider =
    NotifierProvider<TimerController, SleepTimerState>(TimerController.new);
