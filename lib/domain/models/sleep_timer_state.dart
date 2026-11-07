/// Betriebsmodus des Schlaftimers gemaess Nocturne Phase 2.
enum SleepTimerMode {
  /// Schlaftimer ist deaktiviert.
  off,

  /// Manueller Countdown mit fester oder benutzerdefinierter Dauer.
  countdown,

  /// Schlaftimer laeuft bis zum Ende des aktuellen Kapitels.
  untilChapterEnd,
}

/// Zustaende der Schlaftimer-Zustandsmaschine.
enum SleepTimerStatus {
  /// Kein aktiver Timer.
  inactive,

  /// Aktiver Countdown laeuft (Restzeit > 60 Sekunden).
  counting,

  /// Die letzten 60 Sekunden laufen mit kontinuierlichem Lautstaerke-Fade-Out.
  fadingOut,

  /// Audio ist stumm; 120-Sekunden Shake-Grace-Period fuer Schlaferkennung laeuft.
  gracePeriod,

  /// Grace-Period abgelaufen; AudioSession geschlossen und WakeLock freigegeben.
  stopped,
}

/// Alias fuer Rueckwaertskompatibilitaet und klare Semantik.
typedef SleepTimerPhase = SleepTimerStatus;

/// Vordefinierte Countdown-Presets fuer den Schlaftimer.
enum SleepTimerPreset {
  m5,
  m10,
  m15,
  m30,
  m45,
  m60,
  untilChapterEnd,
  custom,
  off;

  Duration? get fixedDuration {
    switch (this) {
      case SleepTimerPreset.m5:
        return const Duration(minutes: 5);
      case SleepTimerPreset.m10:
        return const Duration(minutes: 10);
      case SleepTimerPreset.m15:
        return const Duration(minutes: 15);
      case SleepTimerPreset.m30:
        return const Duration(minutes: 30);
      case SleepTimerPreset.m45:
        return const Duration(minutes: 45);
      case SleepTimerPreset.m60:
        return const Duration(minutes: 60);
      case SleepTimerPreset.untilChapterEnd:
      case SleepTimerPreset.custom:
      case SleepTimerPreset.off:
        return null;
    }
  }

  String get label {
    switch (this) {
      case SleepTimerPreset.m5:
        return '5 min';
      case SleepTimerPreset.m10:
        return '10 min';
      case SleepTimerPreset.m15:
        return '15 min';
      case SleepTimerPreset.m30:
        return '30 min';
      case SleepTimerPreset.m45:
        return '45 min';
      case SleepTimerPreset.m60:
        return '60 min';
      case SleepTimerPreset.untilChapterEnd:
        return 'End of chapter';
      case SleepTimerPreset.custom:
        return 'Custom';
      case SleepTimerPreset.off:
        return 'Off';
    }
  }
}

/// Unveraenderlicher Zustand des Schlaftimers im Domain-Layer.
class SleepTimerState {
  final SleepTimerMode mode;
  final SleepTimerStatus status;
  final Duration totalDuration;
  final Duration remainingDuration;
  final double volumeFactor;
  final SleepTimerPreset preset;
  final Duration extendInterval;
  final Duration gracePeriodRemaining;

  const SleepTimerState({
    SleepTimerMode? mode,
    SleepTimerStatus? status,
    this.totalDuration = Duration.zero,
    this.remainingDuration = Duration.zero,
    double? volumeFactor,
    this.preset = SleepTimerPreset.m30,
    this.extendInterval = const Duration(minutes: 15),
    this.gracePeriodRemaining = const Duration(seconds: 120),
    // Backward compatibility for legacy presentation/timer_providers:
    bool? isActive,
    bool? isFadingOut,
    bool? isGracePeriod,
    double? currentVolume,
  })  : volumeFactor = volumeFactor ?? currentVolume ?? 1.0,
        status = status ??
            (isGracePeriod == true
                ? SleepTimerStatus.gracePeriod
                : (isFadingOut == true
                    ? SleepTimerStatus.fadingOut
                    : (isActive == true
                        ? SleepTimerStatus.counting
                        : SleepTimerStatus.inactive))),
        mode = mode ??
            (preset == SleepTimerPreset.untilChapterEnd
                ? SleepTimerMode.untilChapterEnd
                : ((isActive == true ||
                        status == SleepTimerStatus.counting ||
                        status == SleepTimerStatus.fadingOut ||
                        status == SleepTimerStatus.gracePeriod)
                    ? SleepTimerMode.countdown
                    : SleepTimerMode.off));

  static const SleepTimerState initial = SleepTimerState(
    mode: SleepTimerMode.off,
    status: SleepTimerStatus.inactive,
    totalDuration: Duration.zero,
    remainingDuration: Duration.zero,
    volumeFactor: 1.0,
    preset: SleepTimerPreset.m30,
    gracePeriodRemaining: Duration(seconds: 120),
  );

  // Kompatibilitaets-Getter fuer Presentation & Controller:
  double get currentVolume => volumeFactor;
  bool get isActive =>
      status == SleepTimerStatus.counting ||
      status == SleepTimerStatus.fadingOut ||
      status == SleepTimerStatus.gracePeriod;
  bool get isCounting => status == SleepTimerStatus.counting;
  bool get isFadingOut => status == SleepTimerStatus.fadingOut;
  bool get isGracePeriod => status == SleepTimerStatus.gracePeriod;
  bool get isStopped =>
      status == SleepTimerStatus.stopped || status == SleepTimerStatus.inactive;

  double get progressFraction {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    final elapsed =
        totalDuration.inMilliseconds - remainingDuration.inMilliseconds;
    final fraction = elapsed / totalDuration.inMilliseconds;
    return fraction.clamp(0.0, 1.0);
  }

  String formatRemaining() {
    final hours = remainingDuration.inHours;
    final minutes = remainingDuration.inMinutes.remainder(60);
    final seconds = remainingDuration.inSeconds.remainder(60);
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  SleepTimerState copyWith({
    SleepTimerMode? mode,
    SleepTimerStatus? status,
    Duration? totalDuration,
    Duration? remainingDuration,
    double? volumeFactor,
    SleepTimerPreset? preset,
    Duration? extendInterval,
    Duration? gracePeriodRemaining,
    // Rueckwaertskompatibilitaet fuer fruehere Notifier-Aufrufe:
    bool? isActive,
    bool? isFadingOut,
    bool? isGracePeriod,
    double? currentVolume,
  }) {
    SleepTimerStatus resolvedStatus = status ?? this.status;
    if (status == null) {
      if (isGracePeriod == true) {
        resolvedStatus = SleepTimerStatus.gracePeriod;
      } else if (isFadingOut == true) {
        resolvedStatus = SleepTimerStatus.fadingOut;
      } else if (isGracePeriod == false &&
          this.status == SleepTimerStatus.gracePeriod) {
        resolvedStatus = (isActive == false)
            ? SleepTimerStatus.stopped
            : SleepTimerStatus.counting;
      } else if (isActive == true &&
          resolvedStatus == SleepTimerStatus.inactive) {
        resolvedStatus = SleepTimerStatus.counting;
      } else if (isActive == false &&
          resolvedStatus != SleepTimerStatus.inactive) {
        resolvedStatus = SleepTimerStatus.stopped;
      }
    }

    SleepTimerMode resolvedMode = mode ?? this.mode;
    if (mode == null) {
      if (preset == SleepTimerPreset.untilChapterEnd) {
        resolvedMode = SleepTimerMode.untilChapterEnd;
      } else if (isActive != null) {
        resolvedMode =
            isActive ? SleepTimerMode.countdown : SleepTimerMode.off;
      } else if (resolvedStatus == SleepTimerStatus.inactive ||
          resolvedStatus == SleepTimerStatus.stopped) {
        resolvedMode = SleepTimerMode.off;
      } else if (resolvedStatus == SleepTimerStatus.counting ||
          resolvedStatus == SleepTimerStatus.fadingOut ||
          resolvedStatus == SleepTimerStatus.gracePeriod) {
        resolvedMode = SleepTimerMode.countdown;
      }
    }

    return SleepTimerState(
      mode: resolvedMode,
      status: resolvedStatus,
      totalDuration: totalDuration ?? this.totalDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      volumeFactor: volumeFactor ?? currentVolume ?? this.volumeFactor,
      preset: preset ?? this.preset,
      extendInterval: extendInterval ?? this.extendInterval,
      gracePeriodRemaining: gracePeriodRemaining ?? this.gracePeriodRemaining,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerState &&
          mode == other.mode &&
          status == other.status &&
          totalDuration == other.totalDuration &&
          remainingDuration == other.remainingDuration &&
          volumeFactor == other.volumeFactor &&
          preset == other.preset &&
          extendInterval == other.extendInterval &&
          gracePeriodRemaining == other.gracePeriodRemaining;

  @override
  int get hashCode => Object.hash(
        mode,
        status,
        totalDuration,
        remainingDuration,
        volumeFactor,
        preset,
        extendInterval,
        gracePeriodRemaining,
      );

  @override
  String toString() =>
      'SleepTimerState(mode: ${mode.name}, status: ${status.name}, remaining: ${formatRemaining()}, vol: ${(volumeFactor * 100).round()}%)';
}
