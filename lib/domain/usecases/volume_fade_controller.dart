import 'dart:async';
import '../models/sleep_timer_state.dart';
import '../repositories/audio_player_repository.dart';
import 'sleep_timer_state_machine.dart';

/// Steuert den quadratisch-logarithmischen Lautstaerke-Fade-Out fuer die Bedtime Engine.
///
/// Formel gemaess Spezifikation:
/// Volume(t) = Volume_start * (t_rest / 60)^2
///
/// Reines Dart im Domain-Layer ohne Flutter-Abhaengigkeiten.
class VolumeFadeController {
  /// Dauer der Ausblendblende (60 Sekunden).
  static const Duration defaultFadeDuration = Duration(seconds: 60);

  /// Zeitschritt fuer hochaufloesende mikroakustische Rampen (50 Millisekunden).
  static const Duration defaultRampStepInterval = Duration(milliseconds: 50);

  final AudioPlayerRepository? _playerRepository;
  final Duration fadeDuration;
  final StreamController<double> _volumeFactorController =
      StreamController<double>.broadcast();

  double _volumeStart;
  double _currentFactor = 1.0;
  StreamSubscription<SleepTimerState>? _stateMachineSub;
  Timer? _activeRampTimer;

  VolumeFadeController({
    AudioPlayerRepository? playerRepository,
    double initialVolume = 1.0,
    this.fadeDuration = defaultFadeDuration,
  })  : _playerRepository = playerRepository,
        _volumeStart = initialVolume.clamp(0.0, 1.0);

  /// Ausgangslautstaerke des Hoerers vor Beginn des Fade-Outs (0.0 bis 1.0).
  double get volumeStart => _volumeStart;

  set volumeStart(double value) {
    _volumeStart = value.clamp(0.0, 1.0);
  }

  /// Aktueller relativer Lautstaerkefaktor (0.0 bis 1.0).
  double get currentFactor => _currentFactor;

  /// Effektive Lautstaerke bezogen auf volumeStart: Volume_start * Factor.
  double get effectiveVolume => (_volumeStart * _currentFactor).clamp(0.0, 1.0);

  /// Stream des relativen Lautstaerkefaktors.
  Stream<double> get volumeFactorStream => _volumeFactorController.stream;

  /// Berechnet den mathematisch exakten Drosselungsfaktor fuer eine gegebene Restzeit:
  /// factor = (t_rest / 60)^2
  static double calculateFactor(
    Duration remaining, {
    Duration fadeDuration = defaultFadeDuration,
  }) {
    if (remaining <= Duration.zero) {
      return 0.0;
    }
    if (remaining >= fadeDuration) {
      return 1.0;
    }

    final remainingMs = remaining.inMilliseconds.toDouble();
    final totalFadeMs = fadeDuration.inMilliseconds.toDouble();
    final fraction = (remainingMs / totalFadeMs).clamp(0.0, 1.0);

    return fraction * fraction;
  }

  /// Erzeugt eine vollstaendige Liste diskreter Pegelschritte entlang der Blende.
  /// Nuetzlich fuer Audio-Ramp-Validierung und klickfreie Wiedergabepuffer.
  static List<double> generateRampSteps({
    Duration fadeDuration = defaultFadeDuration,
    Duration stepInterval = defaultRampStepInterval,
    double volumeStart = 1.0,
  }) {
    final startClamped = volumeStart.clamp(0.0, 1.0);
    final totalSteps =
        (fadeDuration.inMilliseconds / stepInterval.inMilliseconds).round();
    final steps = <double>[];

    for (var i = 0; i <= totalSteps; i++) {
      final remainingMs =
          fadeDuration.inMilliseconds - (i * stepInterval.inMilliseconds);
      final remaining = Duration(
          milliseconds: remainingMs.clamp(0, fadeDuration.inMilliseconds));
      final factor = calculateFactor(remaining, fadeDuration: fadeDuration);
      steps.add((startClamped * factor).clamp(0.0, 1.0));
    }

    return steps;
  }

  /// Aktualisiert den Lautstaerkefaktor basierend auf der aktuellen Restzeit
  /// und uebermittelt ihn direkt an das Audio-Repository.
  Future<void> updateForRemaining(Duration remaining) async {
    _cancelRampTimer();
    final factor = calculateFactor(remaining, fadeDuration: fadeDuration);
    await _applyFactor(factor);
  }

  /// Bindet diesen Controller direkt an eine [SleepTimerStateMachine].
  ///
  /// Reagiert automatisch auf Zustandswechsel:
  /// - [SleepTimerStatus.fadingOut]: Wendet die logarithmische Kurve an.
  /// - [SleepTimerStatus.gracePeriod] oder [SleepTimerStatus.stopped]: Setzt Lautstaerke auf 0.0.
  /// - Wechsel zurueck zu [SleepTimerStatus.counting] (z. B. nach Schuetteln):
  ///   Stellt Lautstaerke klickfrei wieder her.
  void attachStateMachine(SleepTimerStateMachine stateMachine) {
    _stateMachineSub?.cancel();
    _stateMachineSub = stateMachine.stateStream.listen((state) {
      // Veraltete Stream-Ereignisse verwerfen, falls sich der Status bereits weiterbewegt hat
      if (stateMachine.state.status != state.status) {
        return;
      }

      switch (state.status) {
        case SleepTimerStatus.counting:
          if (_currentFactor < 1.0) {
            // Nach Shake waehrend Fade-Out sofort klickfrei wiederherstellen
            restoreVolumeInstant();
          }
          break;
        case SleepTimerStatus.fadingOut:
          updateForRemaining(state.remainingDuration);
          break;
        case SleepTimerStatus.gracePeriod:
        case SleepTimerStatus.stopped:
          muteInstant();
          break;
        case SleepTimerStatus.inactive:
          if (_currentFactor < 1.0) {
            restoreVolumeInstant();
          }
          break;
      }
    });
  }

  /// Setzt die Lautstaerke sofort auf die Ausgangslautstaerke zurueck (100% von volumeStart).
  Future<void> restoreVolumeInstant() async {
    _cancelRampTimer();
    await _applyFactor(1.0);
  }

  /// Stellt die Lautstaerke ueber eine sanfte Mikrorampe wieder her (z. B. nach Aufwecken),
  /// um Plopp- und Klickgeraeusche auf Lautsprechern vollstaendig zu vermeiden.
  Future<void> restoreVolumeSmooth({
    Duration duration = const Duration(milliseconds: 250),
    Duration stepInterval = const Duration(milliseconds: 25),
  }) async {
    _cancelRampTimer();
    final startFactor = _currentFactor;
    if (startFactor >= 1.0) return;

    final stepsCount =
        (duration.inMilliseconds / stepInterval.inMilliseconds).round();
    if (stepsCount <= 1) {
      await restoreVolumeInstant();
      return;
    }

    final completer = Completer<void>();
    var currentStep = 0;

    _activeRampTimer = Timer.periodic(stepInterval, (timer) async {
      currentStep++;
      final progress = (currentStep / stepsCount).clamp(0.0, 1.0);
      final newFactor = startFactor + (1.0 - startFactor) * progress;
      await _applyFactor(newFactor);

      if (currentStep >= stepsCount) {
        timer.cancel();
        _activeRampTimer = null;
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Setzt die Lautstaerke unverzueglich auf 0 (Stille).
  Future<void> muteInstant() async {
    _cancelRampTimer();
    await _applyFactor(0.0);
  }

  Future<void> _applyFactor(double factor) async {
    _currentFactor = factor.clamp(0.0, 1.0);
    if (!_volumeFactorController.isClosed) {
      _volumeFactorController.add(_currentFactor);
    }

    final repo = _playerRepository;
    if (repo != null) {
      await repo.setVolume(effectiveVolume);
    }
  }

  void _cancelRampTimer() {
    _activeRampTimer?.cancel();
    _activeRampTimer = null;
  }

  /// Gibt belegte Streams und Abonnements frei.
  Future<void> dispose() async {
    _cancelRampTimer();
    await _stateMachineSub?.cancel();
    _stateMachineSub = null;
    await _volumeFactorController.close();
  }
}
