import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/screens/bedtime_screen.dart';
import 'package:nocturne/presentation/widgets/bed_lock_overlay.dart';

class MockAudioPlayerRepository implements AudioPlayerRepository {
  AudioPlaybackStatus currentStatus = AudioPlaybackStatus.idle;
  Duration currentPosition = const Duration(minutes: 5);
  Duration? lastSoughtPosition;
  bool isPlaying = false;
  bool isPaused = false;

  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream async* {
    yield currentStatus;
    yield* _statusCtrl.stream;
  }

  @override
  Stream<Duration> get positionStream async* {
    yield currentPosition;
    yield* _posCtrl.stream;
  }

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(minutes: 60));

  @override
  Stream<double> get volumeStream => Stream.value(1.0);

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    currentStatus = AudioPlaybackStatus.ready;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    isPaused = false;
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
    currentStatus = AudioPlaybackStatus.idle;
    _statusCtrl.add(currentStatus);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSoughtPosition = position;
    currentPosition = position;
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
  }
}

void main() {
  group('Bed-Lock Touch-Sperre Widget Tests (TICK-028)', () {
    late MockAudioPlayerRepository mockAudio;

    setUp(() {
      mockAudio = MockAudioPlayerRepository();
    });

    tearDown(() async {
      await mockAudio.dispose();
    });

    Widget createTestWidget({List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockAudio),
          ...overrides,
        ],
        child: const MaterialApp(
          home: BedtimeScreen(),
        ),
      );
    }

    testWidgets('One-Click activation locks the player and shows dimmed scrim',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Anfangs nicht gesperrt
      expect(find.byType(BedLockOverlay), findsOneWidget);
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsNothing);

      // Klick auf Bed-Lock-Taste
      final lockBtn = find.byKey(const Key('bed_lock_activate_button'));
      expect(lockBtn, findsOneWidget);
      await tester.tap(lockBtn);
      await tester.pumpAndSettle();

      // Bed-Lock ist nun aktiv: Gedaempfte Bildschirmanzeige sichtbar
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsOneWidget);
      expect(find.text('Bed-Lock aktiv'), findsOneWidget);
    });

    testWidgets('While Bed-Lock is active, all normal touch gestures are blocked',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Sperre aktivieren
      await tester.tap(find.byKey(const Key('bed_lock_activate_button')));
      await tester.pumpAndSettle();

      // Tasten-Beruehrungen durch Bettdecke/Kissen simulieren
      final add15Btn = find.byKey(const Key('add_15_minutes_button'));
      final playPauseBtn = find.byKey(const Key('play_pause_button'));

      // Versuch +15 Min zu druecken
      await tester.tap(add15Btn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      // Timer darf nicht veraendert worden sein
      expect(find.text('Aus'), findsOneWidget);

      // Versuch Play/Pause zu druecken
      await tester.tap(playPauseBtn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      // Audio darf nicht gestartet worden sein
      expect(mockAudio.isPlaying, isFalse);
    });

    testWidgets('Short press does NOT unlock; full 2-second hold unlocks player',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Sperren
      await tester.tap(find.byKey(const Key('bed_lock_activate_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsOneWidget);

      final lockGestureArea = find.byKey(const Key('bed_lock_gesture_detector'));

      // 1. Kurzer Touch von 500 ms (unbeabsichtigte Bettdeckenberuehrung)
      final gesture = await tester.startGesture(tester.getCenter(lockGestureArea));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      // Bleibt weiterhin gesperrt!
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsOneWidget);

      // 2. Bewusstes langes Druecken von 2 Sekunden
      final longPressGesture = await tester.startGesture(tester.getCenter(lockGestureArea));
      // 2100 ms vergehen lassen (ueberschreitet die 2000 ms Schwelle sicher)
      await tester.pump(const Duration(milliseconds: 2100));
      await longPressGesture.up();
      await tester.pumpAndSettle();

      // Vollstaendig entsperrt! Gedaempfter Schleier verschwunden
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsNothing);
    });

    testWidgets('Swipe-up gesture unlocks player immediately',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Sperren
      await tester.tap(find.byKey(const Key('bed_lock_activate_button')));
      await tester.pumpAndSettle();

      final lockGestureArea = find.byKey(const Key('bed_lock_gesture_detector'));

      // Wischgeste nach oben
      await tester.drag(lockGestureArea, const Offset(0.0, -200.0));
      await tester.pumpAndSettle();

      // Durch Wischgeste entsperrt!
      expect(find.byKey(const Key('bed_lock_dimmed_scrim')), findsNothing);
    });
  });
}
