import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/screens/bedtime_screen.dart';
import 'package:nocturne/presentation/widgets/sleep_timer_circular_hud.dart';
import 'package:nocturne/presentation/widgets/sleep_timer_picker_sheet.dart';

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
  Future<void> setSource(AudioSourceRef source,
      {Duration? initialPosition}) async {
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
  group('BedtimeScreen & Circular HUD Widget Tests (TICK-027)', () {
    late MockAudioPlayerRepository mockAudio;

    setUp(() {
      mockAudio = MockAudioPlayerRepository();
    });

    tearDown(() async {
      await mockAudio.dispose();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockAudio),
        ],
        child: const MaterialApp(
          home: BedtimeScreen(),
        ),
      );
    }

    testWidgets('Renders Circular Countdown HUD and opens SleepTimerPickerSheet on tap',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Circular HUD vorhanden
      expect(find.byType(SleepTimerCircularHud), findsOneWidget);
      expect(find.text('Aus'), findsOneWidget);
      expect(find.text('Timer starten'), findsOneWidget);

      // Tippen auf Circular HUD oeffnet SleepTimerPickerSheet
      await tester.tap(find.byKey(const Key('sleep_timer_circular_hud')));
      await tester.pumpAndSettle();

      expect(find.byType(SleepTimerPickerSheet), findsOneWidget);
      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);

      // Preset 30 min auswaehlen
      await tester.tap(find.byKey(const Key('sleep_timer_preset_30')));
      await tester.pumpAndSettle();

      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('Schlaftimer aktiv'), findsOneWidget);
    });

    testWidgets('Dedicated sleep timer button opens picker sheet with all presets',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final menuBtn = find.byKey(const Key('sleep_timer_menu_button'));
      expect(menuBtn, findsOneWidget);

      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SleepTimerPickerSheet), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_custom_chip')), findsOneWidget);
    });

    testWidgets('One-Tap +15 Min button extends timer immediately',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final add15Btn = find.byKey(const Key('add_15_minutes_button'));
      expect(add15Btn, findsOneWidget);
      expect(find.text('+15 Min'), findsOneWidget);

      // Klick auf +15 Min bei inaktivem Timer startet 15 Minuten
      await tester.tap(add15Btn);
      await tester.pumpAndSettle();

      expect(find.text('15:00'), findsOneWidget);

      // Weiterer Klick auf +15 Min erhoeht auf 30 Minuten
      await tester.tap(add15Btn);
      await tester.pumpAndSettle();

      expect(find.text('30:00'), findsOneWidget);
    });

    testWidgets(
        'Shake profile badge displays and toggles between Nightstand and Mattress',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final profileToggle = find.byKey(const Key('sensor_profile_toggle'));
      expect(profileToggle, findsOneWidget);

      // Standard: Nachttisch / Hand
      expect(find.text('Nachttisch / Hand'), findsOneWidget);

      // Tap wechselt zu Matratze / Kissen
      await tester.tap(profileToggle);
      await tester.pumpAndSettle();

      expect(find.text('Matratze / Kissen'), findsOneWidget);

      // Erneuter Tap wechselt zurueck zu Nachttisch / Hand
      await tester.tap(profileToggle);
      await tester.pumpAndSettle();

      expect(find.text('Nachttisch / Hand'), findsOneWidget);
    });

    testWidgets(
        'Large transport buttons jump 15s and support continuous hold seeking (TICK-V2-04)',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final rewindBtn = find.byKey(const Key('rewind_15_button'));
      final playPauseBtn = find.byKey(const Key('play_pause_button'));
      final forwardBtn = find.byKey(const Key('forward_15_button'));

      expect(rewindBtn, findsOneWidget);
      expect(playPauseBtn, findsOneWidget);
      expect(forwardBtn, findsOneWidget);

      // Play/Pause betaetigen
      await tester.tap(playPauseBtn);
      await tester.pumpAndSettle();
      expect(mockAudio.isPlaying, isTrue);

      // 15s Rueckwaerts betaetigen: 300s - 15s = 285s
      await tester.tap(rewindBtn);
      await tester.pumpAndSettle();
      expect(mockAudio.lastSoughtPosition, const Duration(seconds: 285));

      // 15s Vorwaerts betaetigen: 285s + 15s = 300s
      await tester.tap(forwardBtn);
      await tester.pumpAndSettle();
      expect(mockAudio.lastSoughtPosition, const Duration(seconds: 300));

      // Long-press hold-seeking: 1 continuous tick immediately (-5s) -> 295s
      final gesture = await tester.startGesture(tester.getCenter(rewindBtn));
      await tester.pump(const Duration(milliseconds: 600)); // Triggers long-press start
      expect(mockAudio.lastSoughtPosition, const Duration(seconds: 295));

      // Another 200ms -> next 5s step -> 290s
      await tester.pump(const Duration(milliseconds: 250));
      expect(mockAudio.lastSoughtPosition, const Duration(seconds: 290));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
