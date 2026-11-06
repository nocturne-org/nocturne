import 'dart:async';
import '../models/sleep_timer_state.dart';

/// Typdefinitionen fuer Ereignis-Rueckrufe der Schlaftimer-Zustandsmaschine.
typedef VolumeChangedCallback = void Function(double volumeFactor);
typedef GracePeriodStartedCallback = void Function(Duration bookmarkRewindOffset);
typedef TimerStoppedCallback = void Function();
typedef TimerExtendedCallback = void Function(Duration newRemaining);

/// Reaktive Zustandsmaschine fuer den Bedtime SleepTimer.
///
/// Implementiert die exakten Uebergaenge gemaess Nocturne-Architektur:
/// [SleepTimerStatus.inactive] -> [SleepTimerStatus.counting] ->
/// [SleepTimerStatus.fadingOut] (<= 60s) -> [SleepTimerStatus.gracePeriod] (120s) ->
/// [SleepTimerStatus.stopped].
///
/// Reines Dart ohne Abhaengigkeiten zum Flutter-Framework.
class SleepTimerStateMachine {
  /// Dauer der Ausblendphase (Fade-Out) in Sekunden.
  static const Duration fadeOutDuration = Duration(seconds: 60);

  /// Dauer der Shake-Grace-Period vor dem endgueltigen Stop.
  static const Duration gracePeriodDuration = Duration(seconds: 120);

  /// Lesezeichen-Offset vor Beginn des Fade-Outs (45s vor Fade-Start = 105s vor Stille).
  static const Duration bookmarkOffsetBeforeFadeOut = Duration(seconds: 45);

  /// Gesamter Rewind-Offset ab Stoppunkt fuer Lesezeichen (60s Fade + 45s Offset).
  static const Duration totalBookmarkRewindOffset = Duration(seconds: 105);

  /// Standard-Verlaengerungsintervall bei Schuetteln.
  static const Duration defaultExtendInterval = Duration(minutes: 15);

  final StreamController<SleepTimerState> _stateController =
      StreamController<SleepTimerState>.broadcast();

  Timer? _internalTicker;
  SleepTimerState _state = SleepTimerState.initial;

  /// Optionale Rueckrufe fuer Audio-Engine und Plattform-Treiber.
  VolumeChangedCallback? onVolumeChanged;
  GracePeriodStartedCallback? onGracePeriodStarted;
  TimerStoppedCallback? onTimerStopped;
  TimerExtendedCallback? onExtended;

  SleepTimerStateMachine({
    this.onVolumeChanged,
    this.onGracePeriodStarted,
    this.onTimerStopped,
    this.onExtended,
  });

  /// Liefert den aktuellen Schlaftimer-Zustand.
  SleepTimerState get state => _state;

  /// Reaktiver Broadcast-Stream von Zustandsaenderungen.
  Stream<SleepTimerState> get stateStream => _stateController.stream;

  /// Startet den Timer mit einer expliziten Dauer und einem Preset.
  void start({
    required Duration duration,
    SleepTimerPreset preset = SleepTimerPreset.custom,
    Duration extendInterval = defaultExtendInterval,
    bool enableAutoTick = true,
  }) {
    if (duration <= Duration.zero) {
      stop();
      return;
    }

    _stopInternalTicker();

    final isImmediateFade = duration <= fadeOutDuration;
    final initialStatus =
        isImmediateFade ? SleepTimerStatus.fadingOut : SleepTimerStatus.counting;
    final initialVolume = isImmediateFade
        ? _calculateFadeVolume(duration)
        : 1.0;

    _updateState(
      SleepTimerState(
        status: initialStatus,
        totalDuration: duration,
        remainingDuration: duration,
        volumeFactor: initialVolume,
        preset: preset,
        extendInterval: extendInterval,
      ),
    );

    onVolumeChanged?.call(initialVolume);

    if (enableAutoTick) {
      _startInternalTicker();
    }
  }

  /// Startet den Timer basierend auf einem vordefinierten Preset.
  void startWithPreset(
    SleepTimerPreset preset, {
    Duration? chapterRemaining,
    Duration extendInterval = defaultExtendInterval,
    bool enableAutoTick = true,
  }) {
    final Duration duration;
    if (preset == SleepTimerPreset.untilChapterEnd) {
      duration = chapterRemaining ?? Duration.zero;
    } else if (preset.fixedDuration != null) {
      duration = preset.fixedDuration!;
    } else {
      duration = const Duration(minutes: 30);
    }

    start(
      duration: duration,
      preset: preset,
      extendInterval: extendInterval,
      enableAutoTick: enableAutoTick,
    );
  }

  /// Fuehrt einen diskreten Zeitschritt aus (deterministisch fuer Tests und Timer).
  void tick(Duration delta) {
    if (!_state.isActive || delta <= Duration.zero) {
      return;
    }

    switch (_state.status) {
      case SleepTimerStatus.counting:
        _handleCountingTick(delta);
        break;
      case SleepTimerStatus.fadingOut:
        _handleFadingOutTick(delta);
        break;
      case SleepTimerStatus.gracePeriod:
        _handleGracePeriodTick(delta);
        break;
      case SleepTimerStatus.inactive:
      case SleepTimerStatus.stopped:
        break;
    }
  }

  void _handleCountingTick(Duration delta) {
    final nextRemaining = _state.remainingDuration - delta;

    if (nextRemaining <= Duration.zero) {
      _transitionToGracePeriod();
    } else if (nextRemaining <= fadeOutDuration) {
      final vol = _calculateFadeVolume(nextRemaining);
      _updateState(
        _state.copyWith(
          status: SleepTimerStatus.fadingOut,
          remainingDuration: nextRemaining,
          volumeFactor: vol,
        ),
      );
      onVolumeChanged?.call(vol);
    } else {
      _updateState(
        _state.copyWith(
          remainingDuration: nextRemaining,
        ),
      );
    }
  }

  void _handleFadingOutTick(Duration delta) {
    final nextRemaining = _state.remainingDuration - delta;

    if (nextRemaining <= Duration.zero) {
      _transitionToGracePeriod();
    } else {
      final vol = _calculateFadeVolume(nextRemaining);
      _updateState(
        _state.copyWith(
          remainingDuration: nextRemaining,
          volumeFactor: vol,
        ),
      );
      onVolumeChanged?.call(vol);
    }
  }

  void _handleGracePeriodTick(Duration delta) {
    final nextRemaining = _state.remainingDuration - delta;

    if (nextRemaining <= Duration.zero) {
      _transitionToStopped();
    } else {
      _updateState(
        _state.copyWith(
          remainingDuration: nextRemaining,
        ),
      );
    }
  }

  /// Berechnet die logarithmische Lautstaerke im Fade-Out:
  /// V(t) = (t_rest / 60)^2
  double _calculateFadeVolume(Duration remaining) {
    if (remaining <= Duration.zero) return 0.0;
    final seconds = remaining.inMilliseconds / 1000.0;
    final totalFadeSeconds = fadeOutDuration.inSeconds.toDouble();
    final fraction = (seconds / totalFadeSeconds).clamp(0.0, 1.0);
    return fraction * fraction;
  }

  void _transitionToGracePeriod() {
    _updateState(
      _state.copyWith(
        status: SleepTimerStatus.gracePeriod,
        remainingDuration: gracePeriodDuration,
        volumeFactor: 0.0,
      ),
    );
    onVolumeChanged?.call(0.0);
    onGracePeriodStarted?.call(totalBookmarkRewindOffset);
  }

  void _transitionToStopped() {
    _stopInternalTicker();
    _updateState(
      _state.copyWith(
        status: SleepTimerStatus.stopped,
        remainingDuration: Duration.zero,
        volumeFactor: 0.0,
      ),
    );
    onTimerStopped?.call();
  }

  /// Behandelt ein registriertes Schuettel-Ereignis des Sensors.
  ///
  /// - In [counting]: Verlaengert Restzeit um extendInterval.
  /// - In [fadingOut]: Setzt Lautstaerke sofort auf 1.0, verlaengert Restzeit und wechselt zu [counting].
  /// - In [gracePeriod]: Beendet Stille, setzt Lautstaerke auf 1.0, verlaengert Restzeit und wechselt zu [counting].
  /// - In [inactive] oder [stopped]: Keine Auswirkung.
  bool onShakeDetected() {
    if (!_state.isActive) {
      return false;
    }

    final extendBy = _state.extendInterval;

    switch (_state.status) {
      case SleepTimerStatus.counting:
        final newRemaining = _state.remainingDuration + extendBy;
        final newTotal = _state.totalDuration + extendBy;
        _updateState(
          _state.copyWith(
            remainingDuration: newRemaining,
            totalDuration: newTotal,
          ),
        );
        onExtended?.call(newRemaining);
        return true;

      case SleepTimerStatus.fadingOut:
        final newRemaining = _state.remainingDuration + extendBy;
        final newTotal = _state.totalDuration + extendBy;
        _updateState(
          _state.copyWith(
            status: SleepTimerStatus.counting,
            remainingDuration: newRemaining,
            totalDuration: newTotal,
            volumeFactor: 1.0,
          ),
        );
        onVolumeChanged?.call(1.0);
        onExtended?.call(newRemaining);
        return true;

      case SleepTimerStatus.gracePeriod:
        // Aus Stille wieder aufwecken und Wiedergabe fortsetzen
        final newRemaining = extendBy;
        _updateState(
          _state.copyWith(
            status: SleepTimerStatus.counting,
            remainingDuration: newRemaining,
            totalDuration: newRemaining,
            volumeFactor: 1.0,
          ),
        );
        onVolumeChanged?.call(1.0);
        onExtended?.call(newRemaining);
        return true;

      case SleepTimerStatus.inactive:
      case SleepTimerStatus.stopped:
        return false;
    }
  }

  /// Manuelle Verlaengerung (z. B. via Button in der Benutzeroberflaeche).
  void extend([Duration? customDuration]) {
    final extendBy = customDuration ?? _state.extendInterval;
    if (_state.isActive) {
      final newRemaining = _state.remainingDuration + extendBy;
      final newTotal = _state.totalDuration + extendBy;
      _updateState(
        _state.copyWith(
          status: SleepTimerStatus.counting,
          remainingDuration: newRemaining,
          totalDuration: newTotal,
          volumeFactor: 1.0,
        ),
      );
      onVolumeChanged?.call(1.0);
      onExtended?.call(newRemaining);
    }
  }

  /// Bricht den Timer ab und setzt den Zustand zurueck auf [SleepTimerStatus.inactive].
  void cancel() {
    _stopInternalTicker();
    _updateState(SleepTimerState.initial);
    onVolumeChanged?.call(1.0);
  }

  /// Stoppt den Timer vollstaendig (uebergang in [SleepTimerStatus.stopped]).
  void stop() {
    _transitionToStopped();
  }

  void _updateState(SleepTimerState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _startInternalTicker() {
    _stopInternalTicker();
    _internalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      tick(const Duration(seconds: 1));
    });
  }

  void _stopInternalTicker() {
    _internalTicker?.cancel();
    _internalTicker = null;
  }

  /// Gibt belegte Ressourcen und Streams frei.
  void dispose() {
    _stopInternalTicker();
    _stateController.close();
  }
}
