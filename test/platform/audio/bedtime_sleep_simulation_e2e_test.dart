import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/sensor_profile.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/manage_bedtime_session.dart';
import 'package:nocturne/platform/audio/audio_focus_manager.dart';
import 'package:nocturne/platform/sensors/accelerometer_shake_detector.dart';
import 'package:nocturne/platform/sensors/haptic_feedback_service.dart';
import 'package:nocturne/platform/sensors/models/accelerometer_sample.dart';
import 'package:nocturne/platform/sensors/shake_filter.dart';

/// Test-Fake fuer das [AudioPlayerRepository] im E2E-Nachtzyklus.
class SimulationAudioPlayer implements AudioPlayerRepository {
  AudioPlaybackStatus status = AudioPlaybackStatus.idle;
  Duration position = Duration.zero;
  Duration? lastSoughtPosition;
  double volume = 1.0;
  bool isPlaying = false;
  bool isPaused = false;
  bool isStopped = false;

  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(hours: 3));

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  void emitPosition(Duration pos) {
    position = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> setSource(AudioSourceRef source,
      {Duration? initialPosition}) async {
    status = AudioPlaybackStatus.ready;
    if (initialPosition != null) position = initialPosition;
    _statusCtrl.add(status);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    isPaused = false;
    isStopped = false;
    status = AudioPlaybackStatus.playing;
    _statusCtrl.add(status);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    isPaused = true;
    status = AudioPlaybackStatus.paused;
    _statusCtrl.add(status);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    isPaused = false;
    isStopped = true;
    status = AudioPlaybackStatus.idle;
    _statusCtrl.add(status);
  }

  @override
  Future<void> seek(Duration pos) async {
    lastSoughtPosition = pos;
    position = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    _volCtrl.add(volume);
  }

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TICK-036: End-to-End Schlafsimulations- & Schuetteltest', () {
    late SimulationAudioPlayer audioPlayer;
    late FakeHapticFeedbackService hapticService;
    late AccelerometerShakeDetector shakeDetector;
    late AudioFocusManager audioFocusManager;
    late ManageBedtimeSession bedtimeSession;
    late StreamController<AccelerometerSample> customSensorStream;

    final savedBookmarks = <Bookmark>[];
    final wakeLockStates = <bool>[];
    final sensorStates = <bool>[];

    setUp(() {
      savedBookmarks.clear();
      wakeLockStates.clear();
      sensorStates.clear();

      audioPlayer = SimulationAudioPlayer();
      hapticService = FakeHapticFeedbackService();
      shakeDetector = AccelerometerShakeDetector(
        filter: ShakeFilter(profile: SensorProfileConfig.mattress),
        hapticService: hapticService,
      );
      audioFocusManager = AudioFocusManager();
      customSensorStream = StreamController<AccelerometerSample>.broadcast();
      shakeDetector.startListeningWithCustomStream(customSensorStream.stream);

      bedtimeSession = ManageBedtimeSession(
        audioPlayer: audioPlayer,
        onBookmarkSaved: (b) async => savedBookmarks.add(b),
        onWakeLockChanged: (enabled) async => wakeLockStates.add(enabled),
        onSensorActiveChanged: (enabled) async => sensorStates.add(enabled),
      );

      // Verdrahtung des Sensors mit der Bedtime-Session
      shakeDetector.onShake = () {
        bedtimeSession.handleShake();
      };
    });

    tearDown(() async {
      await bedtimeSession.dispose();
      shakeDetector.stopListening();
      await shakeDetector.dispose();
      await customSensorStream.close();
      await audioFocusManager.dispose();
      await audioPlayer.dispose();
    });

    test(
        'Kompletter 30-Minuten-Einschlafzyklus, Fade-Out, Matratzen-Schuetteln und Bluetooth-Auto-Disconnect',
        () async {
      final baseTime = DateTime(2026, 11, 6, 23, 0, 0);

      // =========================================================================
      // PHASE 1: Session-Start (30 Minuten Schlaftimer, Matratzen-Profil B aktiv)
      // =========================================================================
      await audioPlayer.setSource(
        const AudioSourceRef.file('/storage/bedtime_audiobook.m4b'),
      );
      await audioPlayer.play();
      audioPlayer
          .emitPosition(const Duration(minutes: 10)); // Track bei Minute 10

      await bedtimeSession.startSession(
        mediaItemId: 'audiobook-bedtime-1',
        timerDuration: const Duration(minutes: 30),
        extendInterval: const Duration(minutes: 15),
        userVolume: 0.9,
        enableAutoTick: false,
      );

      expect(bedtimeSession.timerState.status, SleepTimerStatus.counting);
      expect(bedtimeSession.timerState.remainingDuration,
          const Duration(minutes: 30));
      expect(audioPlayer.isPlaying, isTrue);
      // WakeLock und Sensor muessen aktiv sein
      expect(wakeLockStates.last, isTrue);
      expect(sensorStates.last, isTrue);
      expect(shakeDetector.currentProfile.type, SensorProfileType.mattress);

      // =========================================================================
      // PHASE 2: Zeitraffung (Fast-Forward um 29 Minuten bis zum Fade-Out)
      // =========================================================================
      // Audio laeuft parallel 29 Minuten vorwaerts (Start 10m + 29m = 39m)
      audioPlayer.emitPosition(const Duration(minutes: 39));
      bedtimeSession.tick(const Duration(minutes: 29));
      await Future<void>.delayed(Duration.zero);

      // Exakt 60 Sekunden Restzeit -> Fade-Out hat begonnen
      expect(bedtimeSession.timerState.status, SleepTimerStatus.fadingOut);
      expect(bedtimeSession.timerState.remainingDuration,
          const Duration(seconds: 60));

      // 30 Sekunden verstreichen im Fade-Out -> Restzeit 30s
      audioPlayer.emitPosition(const Duration(minutes: 39, seconds: 30));
      bedtimeSession.tick(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);

      // Lautstaerke muss gemaess quadratischer Drosselungskurve gesunken sein:
      // (30/60)^2 = 0.25 -> 0.9 * 0.25 = ca. 0.225
      expect(audioPlayer.volume, closeTo(0.225, 0.01));

      // =========================================================================
      // PHASE 3: Schuetteln auf Matratze waehrend des Fade-Outs (Profil B: > 7.5 m/s²)
      // =========================================================================
      // Hoerer bewegt sich leicht auf Matratze (Amplitude 8.5 m/s²).
      // Bei Matratzen-Profil B (> 7.5 m/s²) muss dies den Reset ausloesen!
      final shakeTime = baseTime.add(const Duration(minutes: 29, seconds: 30));
      shakeDetector.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: shakeTime,
        ),
      );
      final shakeDetected = shakeDetector.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: shakeTime.add(const Duration(milliseconds: 250)),
        ),
      );

      expect(shakeDetected, isTrue);
      expect(hapticService.triggerCount, 1); // Dezentes Haptik-Feedback

      await Future<void>.delayed(Duration.zero);

      // Status muss sofort wieder zu counting zurueckgekehrt sein mit +15 Min Verlaengerung!
      expect(bedtimeSession.timerState.status, SleepTimerStatus.counting);
      expect(
        bedtimeSession.timerState.remainingDuration,
        const Duration(minutes: 15, seconds: 30),
      );
      // Lautstaerke muss unverzueglich wieder auf 100% (0.9) zurueckgesetzt sein
      expect(audioPlayer.volume, closeTo(0.9, 0.01));

      // =========================================================================
      // PHASE 4: Countdown laeuft endgueltig ab -> Wechsel in 120s Grace-Period
      // =========================================================================
      // 14m 30s vorwaerts bis Beginn des zweiten Fade-Outs: Audio laeuft parallel vorwaerts
      audioPlayer.emitPosition(const Duration(minutes: 54));
      bedtimeSession.tick(const Duration(minutes: 14, seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(bedtimeSession.timerState.status, SleepTimerStatus.fadingOut);

      // 60 Sekunden Ausblenden bis Countdown 0 erreicht: Audio laeuft parallel weiter
      audioPlayer.emitPosition(const Duration(minutes: 55));
      bedtimeSession.tick(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);

      // Stille: Grace-Period betreten
      expect(bedtimeSession.timerState.status, SleepTimerStatus.gracePeriod);
      // Audio muss pausiert sein
      expect(audioPlayer.isPaused, isTrue);

      // Auto-Rewind Lesezeichen muss gespeichert worden sein:
      // Fade-Out begann bei 54 Min (3240s) -> 45s davor = 3195s (53m 15s)
      expect(savedBookmarks.length, 1);
      final bookmark = savedBookmarks.first;
      expect(bookmark.position.duration, const Duration(seconds: 3195));
      expect(audioPlayer.lastSoughtPosition, const Duration(seconds: 3195));

      // WakeLock und Sensor bleiben waehrend der 120s Grace-Period AKTIV
      expect(wakeLockStates.last, isTrue);
      expect(sensorStates.last, isTrue);

      // =========================================================================
      // PHASE 5: 120s Grace-Period laeuft ohne Schuetteln ab -> Bluetooth Disconnect
      // =========================================================================
      bedtimeSession.tick(const Duration(seconds: 120));
      await Future<void>.delayed(Duration.zero);

      // Endzustand: stopped
      expect(bedtimeSession.timerState.status, SleepTimerStatus.stopped);
      // AudioSession beendet
      expect(audioPlayer.isStopped, isTrue);

      // Bluetooth Auto-Disconnect: abandonAudioFocus aufrufen
      await audioFocusManager.abandonFocus();
      expect(audioFocusManager.isFocusActive, isFalse);

      // WakeLock und Sensor freigegeben (keine offenen Locks)
      expect(wakeLockStates.last, isFalse);
      expect(sensorStates.last, isFalse);

      shakeDetector.stopListening();
      expect(shakeDetector.isListening, isFalse);
    });

    test('Profil A (Nachttisch) ignoriert sanfte Matratzenbewegung (8.5 m/s²)',
        () async {
      // Profil A konfigurieren
      shakeDetector.applyProfile(SensorProfileConfig.nightstand);
      expect(shakeDetector.currentProfile.threshold, 12.0);

      await bedtimeSession.startSession(
        mediaItemId: 'test-item',
        timerDuration: const Duration(seconds: 40), // Direkt im Fade-Out
        enableAutoTick: false,
      );

      final t = DateTime(2026, 11, 6, 23, 45, 0);

      // Schwung mit 8.5 m/s²
      shakeDetector.processSample(
        AccelerometerSample(x: 8.5, y: 0.0, z: 9.81, timestamp: t),
      );
      final detected = shakeDetector.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: t.add(const Duration(milliseconds: 250)),
        ),
      );

      // Profil A (Nachttisch) muss diesen Schwung ignorieren!
      expect(detected, isFalse);
      expect(bedtimeSession.timerState.status, SleepTimerStatus.fadingOut);
    });
  });
}
