import 'dart:async';
import '../models/bookmark.dart';
import '../models/playback_position.dart';
import '../models/sleep_timer_state.dart';
import '../repositories/audio_player_repository.dart';
import 'sleep_timer_state_machine.dart';
import 'volume_fade_controller.dart';

/// Callback-Typen fuer die Bedtime-Session-Orchestrierung.
typedef BookmarkSavedCallback = Future<void> Function(Bookmark bookmark);
typedef WakeLockCallback = Future<void> Function(bool enabled);
typedef SensorActiveCallback = Future<void> Function(bool enabled);

/// Orchestriert die Bedtime-Session gemaess Nocturne-Architektur (TICK-015).
///
/// Verbindet [SleepTimerStateMachine], [VolumeFadeController], [AudioPlayerRepository],
/// die 120-Sekunden Shake-Grace-Period und die automatische Lesezeichenerstellung
/// exakt 45 Sekunden vor Beginn des Fade-Outs (Auto-Rewind).
///
/// Reines Dart im Domain-Layer ohne Flutter-Abhaengigkeiten.
class ManageBedtimeSession {
  /// Dauer des Fade-Outs (60s).
  static const Duration fadeDuration = Duration(seconds: 60);

  /// Dauer des Rewind-Vorlaufs vor Beginn des Fade-Outs (45s).
  static const Duration rewindBeforeFadeDuration = Duration(seconds: 45);

  /// Gesamter Ruecksprung ab Ausblendende (60s Fade + 45s Offset = 105s).
  static const Duration totalAutoRewindOffset = Duration(seconds: 105);

  /// Dauer der Shake-Grace-Period vor dem vollstaendigen Abschalten (120s).
  static const Duration gracePeriodDuration = Duration(seconds: 120);

  final AudioPlayerRepository _audioPlayer;
  final SleepTimerStateMachine _stateMachine;
  final VolumeFadeController _volumeFader;

  BookmarkSavedCallback? onBookmarkSaved;
  WakeLockCallback? onWakeLockChanged;
  SensorActiveCallback? onSensorActiveChanged;

  String? _activeMediaItemId;
  Duration _lastKnownPlaybackPosition = Duration.zero;
  Duration? _positionAtFadeStart;
  StreamSubscription<SleepTimerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  ManageBedtimeSession({
    required AudioPlayerRepository audioPlayer,
    SleepTimerStateMachine? stateMachine,
    VolumeFadeController? volumeFader,
    this.onBookmarkSaved,
    this.onWakeLockChanged,
    this.onSensorActiveChanged,
  })  : _audioPlayer = audioPlayer,
        _stateMachine = stateMachine ?? SleepTimerStateMachine(),
        _volumeFader = volumeFader ??
            VolumeFadeController(
              playerRepository: audioPlayer,
              initialVolume: 1.0,
            ) {
    _initListeners();
  }

  /// Aktueller Zustand der Schlaftimer-Zustandsmaschine.
  SleepTimerState get timerState => _stateMachine.state;

  /// Stream aller Zustandsaenderungen der Session.
  Stream<SleepTimerState> get stateStream => _stateMachine.stateStream;

  /// Aktuell zugewiesene Medien-ID.
  String? get activeMediaItemId => _activeMediaItemId;

  /// Letzte gemeldete Wiedergabeposition.
  Duration get lastKnownPlaybackPosition => _lastKnownPlaybackPosition;

  /// Startet eine neue Bedtime-Session mit definierter Timerdauer.
  Future<void> startSession({
    required String mediaItemId,
    required Duration timerDuration,
    SleepTimerPreset preset = SleepTimerPreset.custom,
    Duration extendInterval = const Duration(minutes: 15),
    double userVolume = 1.0,
    bool enableAutoTick = true,
  }) async {
    _activeMediaItemId = mediaItemId;
    _positionAtFadeStart = null;
    _volumeFader.volumeStart = userVolume;

    // WakeLock und Sensor fuer die Session aktivieren
    await onWakeLockChanged?.call(true);
    await onSensorActiveChanged?.call(true);

    _stateMachine.start(
      duration: timerDuration,
      preset: preset,
      extendInterval: extendInterval,
      enableAutoTick: enableAutoTick,
    );

    // Initialen Status-Flush fuer Listener sicherstellen
    await Future<void>.delayed(Duration.zero);
  }

  /// Startet eine Bedtime-Session basierend auf einem Preset.
  Future<void> startSessionWithPreset({
    required String mediaItemId,
    required SleepTimerPreset preset,
    Duration? chapterRemaining,
    Duration extendInterval = const Duration(minutes: 15),
    double userVolume = 1.0,
    bool enableAutoTick = true,
  }) async {
    final duration = preset == SleepTimerPreset.untilChapterEnd
        ? (chapterRemaining ?? const Duration(minutes: 30))
        : (preset.fixedDuration ?? const Duration(minutes: 30));

    await startSession(
      mediaItemId: mediaItemId,
      timerDuration: duration,
      preset: preset,
      extendInterval: extendInterval,
      userVolume: userVolume,
      enableAutoTick: enableAutoTick,
    );
  }

  /// Behandelt ein registriertes Schuettel-Ereignis des Beschleunigungssensors.
  Future<bool> handleShake() async {
    final currentStatus = _stateMachine.state.status;
    final handled = _stateMachine.onShakeDetected();

    if (!handled) {
      return false;
    }

    if (currentStatus == SleepTimerStatus.fadingOut) {
      // Lautstaerke unverzueglich wieder auf 100% setzen
      await _volumeFader.restoreVolumeInstant();
    } else if (currentStatus == SleepTimerStatus.gracePeriod) {
      // Aus Stille erwacht: Wiedergabe mit sanftem Fade-In reaktivieren
      await _audioPlayer.play();
      await _volumeFader.restoreVolumeSmooth(
        duration: const Duration(milliseconds: 300),
      );
    }

    return true;
  }

  /// Treibt die Zustandsmaschine deterministisch um [delta] voran (fuer Tests und Ticker).
  void tick(Duration delta) {
    _stateMachine.tick(delta);
  }

  /// Bricht die Bedtime-Session ab und stellt den Normalbetrieb wieder her.
  Future<void> cancelSession() async {
    _stateMachine.cancel();
    await _volumeFader.restoreVolumeInstant();
    await onWakeLockChanged?.call(false);
    await onSensorActiveChanged?.call(false);
  }

  /// Initialisiert die internen Rueckrufe und State-Listener.
  void _initListeners() {
    _volumeFader.attachStateMachine(_stateMachine);

    // Position des Audioplayers beobachten
    _positionSub = _audioPlayer.positionStream.listen((position) {
      _lastKnownPlaybackPosition = position;
    });

    // Zustandsuebergaenge auswerten
    _stateSub = _stateMachine.stateStream.listen((state) async {
      if (state.status == SleepTimerStatus.fadingOut &&
          _positionAtFadeStart == null) {
        _positionAtFadeStart = _lastKnownPlaybackPosition;
      } else if (state.status == SleepTimerStatus.gracePeriod) {
        await _handleGracePeriodEntered();
      } else if (state.status == SleepTimerStatus.stopped) {
        await _handleSessionStopped();
      } else if (state.status == SleepTimerStatus.counting) {
        // Bei Rueckkehr nach Schuetteln Fade-Startpunkt zuruecksetzen
        _positionAtFadeStart = null;
      }
    });
  }

  /// Wird exakt beim Uebergang in die 120s Grace-Period aufgerufen.
  Future<void> _handleGracePeriodEntered() async {
    // 1. Audio pausieren
    await _audioPlayer.pause();

    // 2. Auto-Rewind Lesezeichen berechnen: 45s vor Beginn des Fade-Outs
    final mediaId = _activeMediaItemId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final basePosition = _positionAtFadeStart ?? _lastKnownPlaybackPosition;
      final rewindMs = (basePosition.inMilliseconds -
              rewindBeforeFadeDuration.inMilliseconds)
          .clamp(0, double.maxFinite.toInt());
      final bookmarkPosition = Duration(milliseconds: rewindMs);

      final bookmark = Bookmark(
        id: 'sleep-rewind-${DateTime.now().millisecondsSinceEpoch}',
        mediaItemId: mediaId,
        position: PlaybackPosition(duration: bookmarkPosition),
        createdAt: DateTime.now(),
        label: 'Einschlaf-Lesezeichen (Auto-Rewind)',
        note: 'Automatisch gesetzt 45 Sekunden vor Beginn des Fade-Outs',
      );

      // Lesezeichen ueber den Callback persistieren
      if (onBookmarkSaved != null) {
        await onBookmarkSaved!(bookmark);
      }

      // Audio an die Lesezeichen-Position vorspulen fuer nahtloses Fortsetzen
      await _audioPlayer.seek(bookmarkPosition);
    }

    // 3. Sensor und WakeLock bleiben waehrend der 120s Grace-Period explizit aktiv!
    await onWakeLockChanged?.call(true);
    await onSensorActiveChanged?.call(true);
  }

  /// Wird nach Ablauf der 120s Grace-Period ohne Schuetteln ausgefuehrt.
  Future<void> _handleSessionStopped() async {
    // AudioSession vollstaendig freigeben
    await _audioPlayer.stop();

    // Sensor und WakeLock abschalten
    await onWakeLockChanged?.call(false);
    await onSensorActiveChanged?.call(false);
  }

  /// Raeumt alle Subscriptions und Ressourcen auf.
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    _stateMachine.dispose();
    await _volumeFader.dispose();
  }
}
