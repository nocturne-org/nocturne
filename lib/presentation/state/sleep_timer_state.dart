/// Unveraenderlicher Zustand des Bedtime Sleep-Timers.
class SleepTimerState {
  const SleepTimerState({
    this.isActive = false,
    this.remainingDuration = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isFadingOut = false,
    this.isGracePeriod = false,
    this.currentVolume = 1.0,
    this.gracePeriodRemaining = Duration.zero,
  });

  /// Ob der Sleep-Timer aktiv laeuft oder sich in der Grace-Period befindet.
  final bool isActive;

  /// Verbleibende Restzeit des regulaeren Timers.
  final Duration remainingDuration;

  /// Ursprunglich eingestellte Gesamtdauer des Timers.
  final Duration totalDuration;

  /// Status, ob die letzten 60 Sekunden (Lautstaerke-Fade-Out) aktiv sind.
  final bool isFadingOut;

  /// Status, ob die 120-Sekunden Shake-Grace-Period aktiv ist.
  final bool isGracePeriod;

  /// Aktueller relativer Lautstaerkepegel (0.0 bis 1.0).
  final double currentVolume;

  /// Verbleibende Zeit in der Grace-Period (bis 120s).
  final Duration gracePeriodRemaining;

  /// Inaktiver Ausgangszustand.
  static const SleepTimerState initial = SleepTimerState();

  SleepTimerState copyWith({
    bool? isActive,
    Duration? remainingDuration,
    Duration? totalDuration,
    bool? isFadingOut,
    bool? isGracePeriod,
    double? currentVolume,
    Duration? gracePeriodRemaining,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      isFadingOut: isFadingOut ?? this.isFadingOut,
      isGracePeriod: isGracePeriod ?? this.isGracePeriod,
      currentVolume: currentVolume ?? this.currentVolume,
      gracePeriodRemaining: gracePeriodRemaining ?? this.gracePeriodRemaining,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          remainingDuration == other.remainingDuration &&
          totalDuration == other.totalDuration &&
          isFadingOut == other.isFadingOut &&
          isGracePeriod == other.isGracePeriod &&
          currentVolume == other.currentVolume &&
          gracePeriodRemaining == other.gracePeriodRemaining;

  @override
  int get hashCode => Object.hash(
        isActive,
        remainingDuration,
        totalDuration,
        isFadingOut,
        isGracePeriod,
        currentVolume,
        gracePeriodRemaining,
      );

  @override
  String toString() {
    return 'SleepTimerState(active: $isActive, remaining: ${remainingDuration.inSeconds}s, fade: $isFadingOut, grace: $isGracePeriod, vol: $currentVolume)';
  }
}
