import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/audio/audio_focus_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFocusManager Unit Tests (TICK-006)', () {
    var pauseCount = 0;
    final duckFactors = <double>[];
    late AudioFocusManager manager;

    setUp(() {
      pauseCount = 0;
      duckFactors.clear();

      manager = AudioFocusManager(
        onPauseRequested: () async {
          pauseCount++;
        },
        onVolumeDuckRequested: (factor) async {
          duckFactors.add(factor);
        },
      );
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('Transientes Ducking senkt Lautstaerke ab und stellt sie wieder her',
        () async {
      // Ducking beginnt
      final duckBegin =
          AudioInterruptionEvent(true, AudioInterruptionType.duck);
      await manager.handleInterruption(duckBegin);

      expect(duckFactors, [0.2]);

      // Ducking endet
      final duckEnd = AudioInterruptionEvent(false, AudioInterruptionType.duck);
      await manager.handleInterruption(duckEnd);

      expect(duckFactors, [0.2, 1.0]);
    });

    test('Transiente oder permanente Pause loest onPauseRequested aus',
        () async {
      final pauseEvent =
          AudioInterruptionEvent(true, AudioInterruptionType.pause);
      await manager.handleInterruption(pauseEvent);

      expect(pauseCount, 1);

      final unknownEvent =
          AudioInterruptionEvent(true, AudioInterruptionType.unknown);
      await manager.handleInterruption(unknownEvent);

      expect(pauseCount, 2);
    });

    test(
        'Becoming Noisy pausiert Wiedergabe sofort (Schutz vor Lautsprecher-Lied)',
        () async {
      await manager.handleBecomingNoisy();
      expect(pauseCount, 1);
    });

    test(
        'abandonFocus setzt Fokus zurueck fuer Bluetooth Auto-Disconnect (TICK-018)',
        () async {
      expect(manager.isFocusActive, isFalse);
      await manager.abandonFocus();
      expect(manager.isFocusActive, isFalse);
    });
  });
}
