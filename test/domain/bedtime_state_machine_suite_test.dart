import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/sleep_timer_state.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/manage_bedtime_session.dart';
import 'package:nocturne/domain/usecases/sleep_timer_state_machine.dart';
import 'package:nocturne/domain/usecases/volume_fade_controller.dart';

class SuiteMockAudioPlayer implements AudioPlayerRepository {
  AudioPlaybackStatus currentStatus = AudioPlaybackStatus.idle;
  Duration currentPosition = Duration.zero;
  Duration? soughtPosition;
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
      Stream.value(const Duration(hours: 5));

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  void setPosition(Duration pos) {
    currentPosition = pos;
    _posCtrl.add(pos);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    isPaused = false;
    isStopped = false;
    currentStatus = AudioPlaybackStatus.playing;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    isPaused = true;
    currentStatus = AudioPlaybackStatus.paused;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    isPaused = false;
    isStopped = true;
    currentPosition = Duration.zero;
    currentStatus = AudioPlaybackStatus.idle;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> seek(Duration position) async {
    soughtPosition = position;
    currentPosition = position;
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    _volCtrl.add(volume);
  }

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    currentStatus = AudioPlaybackStatus.ready;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  group('TICK-035: Quadratische Drosselungskurve Mathematische Praezision', () {
    test('Volume(t) = (t_rest / 60)^2 erzeugt absolut monotone Werte ohne Klick-Spruenge', () {
      const fadeDuration = Duration(seconds: 60);

      // Pruefe alle Sekunden von 60s bis 0s
      var previousFactor = 1.0;
      for (var sec = 60; sec >= 0; sec--) {
        final remaining = Duration(seconds: sec);
        final factor = VolumeFadeController.calculateFactor(
          remaining,
          fadeDuration: fadeDuration,
        );

        // Formel-Genauigkeit: (sec / 60)^2
        final expected = (sec / 60.0) * (sec / 60.0);
        expect(factor, closeTo(expected, 0.0001));

        // Monotonie: factor muss <= previousFactor sein
        expect(factor, lessThanOrEqualTo(previousFactor));
        previousFactor = factor;
      }
    });

    test('calculateFactor Grenzwerte und Rundungssicherheit', () {
      // Millisekunden-Genauigkeit
      expect(
        VolumeFadeController.calculateFactor(const Duration(milliseconds: 30000)),
        closeTo(0.25, 0.0001),
      );
      expect(
        VolumeFadeController.calculateFactor(const Duration(milliseconds: 15000)),
        closeTo(0.0625, 0.0001),
      );
      expect(
        VolumeFadeController.calculateFactor(const Duration(milliseconds: 45000)),
        closeTo(0.5625, 0.0001),
      );

      // Negative Werte und Ueberlaeufe klammern stabil
      expect(
        VolumeFadeController.calculateFactor(const Duration(seconds: -1)),
        0.0,
      );
      expect(
        VolumeFadeController.calculateFactor(const Duration(hours: 1)),
        1.0,
      );
    });
  });

  group('TICK-035: Simulation aller SleepTimer State-Machine Uebergaenge', () {
    late SleepTimerStateMachine sm;

    setUp(() {
      sm = SleepTimerStateMachine();
    });

    tearDown(() {
      sm.dispose();
    });

    test('Kompletter Zustandszyklus: inactive -> counting -> fadingOut -> grace -> stopped', () async {
      final statusHistory = <SleepTimerStatus>[];
      final sub = sm.stateStream.listen((s) => statusHistory.add(s.status));

      // 1. Start mit 120 Sekunden
      sm.start(duration: const Duration(seconds: 120), enableAutoTick: false);
      expect(sm.state.status, SleepTimerStatus.counting);
      expect(sm.state.isCounting, isTrue);

      // 2. Ticken um 60s -> Rest 60s -> Uebergang zu fadingOut
      sm.tick(const Duration(seconds: 60));
      expect(sm.state.status, SleepTimerStatus.fadingOut);
      expect(sm.state.isFadingOut, isTrue);

      // 3. Ticken um 60s -> Rest 0s -> Uebergang zu gracePeriod (120s)
      sm.tick(const Duration(seconds: 60));
      expect(sm.state.status, SleepTimerStatus.gracePeriod);
      expect(sm.state.isGracePeriod, isTrue);
      expect(sm.state.volumeFactor, 0.0);
      expect(sm.state.remainingDuration, const Duration(seconds: 120));

      // 4. Grace-Period laeuft ab (120s) -> Uebergang zu stopped
      sm.tick(const Duration(seconds: 120));
      expect(sm.state.status, SleepTimerStatus.stopped);
      expect(sm.state.isStopped, isTrue);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(statusHistory, [
        SleepTimerStatus.counting,
        SleepTimerStatus.fadingOut,
        SleepTimerStatus.gracePeriod,
        SleepTimerStatus.stopped,
      ]);
    });

    test('Schuetteln in jedem Zustand verhaelt sich strikt spezifikationsgemaess', () {
      // Inaktiv: Shake wird ignoriert
      expect(sm.onShakeDetected(), isFalse);

      // Zaehlend: Shake verlaengert Restzeit um 15 Min
      sm.start(duration: const Duration(minutes: 10), enableAutoTick: false);
      expect(sm.onShakeDetected(), isTrue);
      expect(sm.state.remainingDuration, const Duration(minutes: 25));

      // Ausblendend: Shake setzt Lautstaerke sofort auf 1.0 und springt zu counting
      sm.start(duration: const Duration(seconds: 40), enableAutoTick: false);
      expect(sm.state.status, SleepTimerStatus.fadingOut);
      expect(sm.onShakeDetected(), isTrue);
      expect(sm.state.status, SleepTimerStatus.counting);
      expect(sm.state.volumeFactor, 1.0);
      expect(sm.state.remainingDuration, const Duration(minutes: 15, seconds: 40));

      // Grace-Period: Shake weckt das System auf und startet counting mit 15 Min
      sm.tick(const Duration(minutes: 16)); // laeuft in GracePeriod
      expect(sm.state.status, SleepTimerStatus.gracePeriod);
      expect(sm.onShakeDetected(), isTrue);
      expect(sm.state.status, SleepTimerStatus.counting);
      expect(sm.state.remainingDuration, const Duration(minutes: 15));
      expect(sm.state.volumeFactor, 1.0);

      // Gestoppt: Shake wird ignoriert
      sm.stop();
      expect(sm.state.status, SleepTimerStatus.stopped);
      expect(sm.onShakeDetected(), isFalse);
    });

    test('Alle Presets konfigurieren die exakten Zeitspannen', () {
      sm.startWithPreset(SleepTimerPreset.m15, enableAutoTick: false);
      expect(sm.state.remainingDuration, const Duration(minutes: 15));

      sm.startWithPreset(SleepTimerPreset.m30, enableAutoTick: false);
      expect(sm.state.remainingDuration, const Duration(minutes: 30));

      sm.startWithPreset(SleepTimerPreset.m45, enableAutoTick: false);
      expect(sm.state.remainingDuration, const Duration(minutes: 45));

      sm.startWithPreset(SleepTimerPreset.m60, enableAutoTick: false);
      expect(sm.state.remainingDuration, const Duration(minutes: 60));

      sm.startWithPreset(
        SleepTimerPreset.untilChapterEnd,
        chapterRemaining: const Duration(minutes: 7, seconds: 32),
        enableAutoTick: false,
      );
      expect(
        sm.state.remainingDuration,
        const Duration(minutes: 7, seconds: 32),
      );
    });
  });

  group('TICK-035: Verifikation des -45s Auto-Rewind Offsets', () {
    late SuiteMockAudioPlayer mockPlayer;
    late ManageBedtimeSession session;
    final createdBookmarks = <Bookmark>[];

    setUp(() {
      createdBookmarks.clear();
      mockPlayer = SuiteMockAudioPlayer();
      session = ManageBedtimeSession(
        audioPlayer: mockPlayer,
        onBookmarkSaved: (b) async => createdBookmarks.add(b),
      );
    });

    tearDown(() async {
      await session.dispose();
      await mockPlayer.dispose();
    });

    test('Lesezeichen wird exakt 45 Sekunden vor Beginn des Fade-Outs gesetzt', () async {
      await session.startSession(
        mediaItemId: 'audiobook-999',
        timerDuration: const Duration(seconds: 90),
        enableAutoTick: false,
      );

      // Audio spielt bei Position 1200 Sekunden (20 Minuten)
      mockPlayer.setPosition(const Duration(seconds: 1200));

      // 30 Sekunden verstreichen -> 60s Rest -> Fade-Out beginnt bei Pos 1200s
      session.tick(const Duration(seconds: 30));
      expect(session.timerState.status, SleepTimerStatus.fadingOut);

      // Audio laeuft waehrend des 60s Fade-Outs weiter bis Pos 1260s
      mockPlayer.setPosition(const Duration(seconds: 1260));

      // Restliche 60s des Fade-Outs verstreichen -> Stille -> Grace-Period beginnt
      session.tick(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);

      expect(session.timerState.status, SleepTimerStatus.gracePeriod);

      // Verifikation:
      // Fade-Out Beginn war bei 1200s.
      // Offset: 45s vor Fade-Out Beginn -> 1200s - 45s = 1155s (19m 15s)
      expect(createdBookmarks.length, 1);
      final bookmark = createdBookmarks.first;
      expect(bookmark.mediaItemId, 'audiobook-999');
      expect(bookmark.position.duration, const Duration(seconds: 1155));
      expect(bookmark.label, contains('Auto-Rewind'));

      // Audio-Player wurde exakt an die Lesezeichen-Stelle zurueckgespult
      expect(mockPlayer.soughtPosition, const Duration(seconds: 1155));
      expect(mockPlayer.isPaused, isTrue);
    });

    test('Auto-Rewind bei frueher Position (< 45s) klammert fehlerfrei auf 0s', () async {
      await session.startSession(
        mediaItemId: 'intro-track',
        timerDuration: const Duration(seconds: 60),
        enableAutoTick: false,
      );

      // Hoerer schlaeft in den ersten 20 Sekunden ein
      mockPlayer.setPosition(const Duration(seconds: 20));

      // Fade-Out laeuft ab
      session.tick(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);

      expect(createdBookmarks.length, 1);
      // 20s - 45s darf nicht negativ werden -> 0s
      expect(createdBookmarks.first.position.duration, Duration.zero);
      expect(mockPlayer.soughtPosition, Duration.zero);
    });
  });

  group('TICK-035: SleepTimerState Value Object Abdeckung', () {
    test('SleepTimerState initial, copyWith, progressFraction und formatRemaining', () {
      const initial = SleepTimerState.initial;
      expect(initial.isActive, isFalse);
      expect(initial.progressFraction, 0.0);
      expect(initial.formatRemaining(), '00:00');

      final active = initial.copyWith(
        status: SleepTimerStatus.counting,
        totalDuration: const Duration(minutes: 30),
        remainingDuration: const Duration(minutes: 15),
        volumeFactor: 1.0,
      );

      expect(active.isActive, isTrue);
      expect(active.progressFraction, 0.5);
      expect(active.formatRemaining(), '15:00');

      // Stunden-Formatierung
      final withHours = active.copyWith(
        remainingDuration: const Duration(hours: 1, minutes: 15, seconds: 5),
      );
      expect(withHours.formatRemaining(), '01:15:05');

      // Gleichheitspruefung
      final copy = active.copyWith();
      expect(copy, equals(active));
      expect(copy.hashCode, equals(active.hashCode));
      expect(active.toString(), contains('counting'));
    });
  });
}
