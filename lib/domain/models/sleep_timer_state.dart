/// Zustaende der Schlaftimer-Zustandsmaschine gemaess Nocturne-Spezifikation.
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

/// Vordefinierte Countdown-Presets fuer den Schlaftimer.
enum SleepTimerPreset {
  m15,
  m30,
  m45,
  m60,
  untilChapterEnd,
  custom;

  /// Liefert die feste Zeitdauer des Presets (null bei dynamischen Presets).
  Duration? get fixedDuration {
    switch (this) {
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
        return null;
    }
  }

  /// Lesbare deutsche Beschriftung fuer die UI.
  String get label {
    switch (this) {
      case SleepTimerPreset.m15:
        return '15 Min';
      case SleepTimerPreset.m30:
        return '30 Min';
      case SleepTimerPreset.m45:
        return '45 Min';
      case SleepTimerPreset.m60:
        return '60 Min';
      case SleepTimerPreset.untilChapterEnd:
        return 'Bis Kapitelende';
      case SleepTimerPreset.custom:
        return 'Benutzerdefiniert';
    }
  }
}

/// Unveraenderlicher Zustand des Schlaftimers im Domain-Layer.
class SleepTimerState {
  /// Aktueller Status in der State-Machine.
  final SleepTimerStatus status;

  /// Urspruengliche Gesamtdauer des Timers.
  final Duration totalDuration;

  /// Verbleibende Restzeit des aktuellen Zustands.
  final Duration remainingDuration;

  /// Berechneter Lautstaerkefaktor (1.0 = volle Lautstaerke, 0.0 = stumm).
  final double volumeFactor;

  /// Gewaehltes Preset.
  final SleepTimerPreset preset;

  /// Zeitverlaengerung pro Schuettel-Event (Standard: 15 Minuten).
  final Duration extendInterval;

  const SleepTimerState({
    required this.status,
    required this.totalDuration,
    required this.remainingDuration,
    required this.volumeFactor,
    required this.preset,
    this.extendInterval = const Duration(minutes: 15),
  });

  /// Inaktiver Ausgangszustand.
  static const SleepTimerState initial = SleepTimerState(
    status: SleepTimerStatus.inactive,
    totalDuration: Duration.zero,
    remainingDuration: Duration.zero,
    volumeFactor: 1.0,
    preset: SleepTimerPreset.m30,
  );

  /// Ob der Timer aktiv ist (laeuft oder in Grace-Period).
  bool get isActive =>
      status == SleepTimerStatus.counting ||
      status == SleepTimerStatus.fadingOut ||
      status == SleepTimerStatus.gracePeriod;

  /// Ob der Countdown aktiv zaehlt.
  bool get isCounting => status == SleepTimerStatus.counting;

  /// Ob das Audio gerade ausgeblendet wird.
  bool get isFadingOut => status == SleepTimerStatus.fadingOut;

  /// Ob die 120s Shake-Grace-Period aktiv ist.
  bool get isGracePeriod => status == SleepTimerStatus.gracePeriod;

  /// Ob der Timer final gestoppt wurde.
  bool get isStopped => status == SleepTimerStatus.stopped;

  /// Berechnet den linearen Fortschritt von 0.0 bis 1.0.
  double get progressFraction {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    final elapsed =
        totalDuration.inMilliseconds - remainingDuration.inMilliseconds;
    final fraction = elapsed / totalDuration.inMilliseconds;
    return fraction.clamp(0.0, 1.0);
  }

  /// Formatiert die Restzeit im Format "mm:ss" oder "hh:mm:ss".
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

  /// Erzeugt eine modifizierte Kopie dieses [SleepTimerState].
  SleepTimerState copyWith({
    SleepTimerStatus? status,
    Duration? totalDuration,
    Duration? remainingDuration,
    double? volumeFactor,
    SleepTimerPreset? preset,
    Duration? extendInterval,
  }) {
    return SleepTimerState(
      status: status ?? this.status,
      totalDuration: totalDuration ?? this.totalDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      volumeFactor: volumeFactor ?? this.volumeFactor,
      preset: preset ?? this.preset,
      extendInterval: extendInterval ?? this.extendInterval,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerState &&
          status == other.status &&
          totalDuration == other.totalDuration &&
          remainingDuration == other.remainingDuration &&
          volumeFactor == other.volumeFactor &&
          preset == other.preset &&
          extendInterval == other.extendInterval;

  @override
  int get hashCode => Object.hash(
        status,
        totalDuration,
        remainingDuration,
        volumeFactor,
        preset,
        extendInterval,
      );

  @override
  String toString() =>
      'SleepTimerState(status: ${status.name}, remaining: ${formatRemaining()}, vol: ${(volumeFactor * 100).round()}%)';
}
