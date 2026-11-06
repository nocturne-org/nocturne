import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/sensors/accelerometer_shake_detector.dart';
import 'package:nocturne/platform/sensors/haptic_feedback_service.dart';
import 'package:nocturne/platform/sensors/models/accelerometer_sample.dart';
import 'package:nocturne/platform/sensors/shake_filter.dart';

void main() {
  group('ShakeFilter Logic Tests (TICK-016)', () {
    late ShakeFilter filter;
    final baseTime = DateTime(2026, 11, 6, 12, 0, 0);

    setUp(() {
      filter = ShakeFilter(threshold: 12.0);
    });

    test(
        'Continuous gravity vector (~9.81 m/s^2) is filtered out without shake',
        () {
      // 50 Messwerte mit reiner Erdanziehungskraft auf Z-Achse
      for (var i = 0; i < 50; i++) {
        final sample = AccelerometerSample(
          x: 0.05,
          y: -0.05,
          z: 9.81,
          timestamp: baseTime.add(Duration(milliseconds: i * 20)),
        );
        final detected = filter.processSample(sample);
        expect(detected, isFalse);
      }

      // Gravitationsschaetzer hat sich auf ca. 9.81 eingeschwungen
      expect(filter.gravityZ, closeTo(9.81, 0.2));
    });

    test(
        'Breathing movements (low-frequency slow sinusoidal sway) are filtered out',
        () {
      // Simulation von 10 Sekunden Atembewegung: 0.25 Hz Sinus mit kleiner Amplitude (0.3 m/s^2)
      for (var i = 0; i < 200; i++) {
        final timeMs = i * 50; // 20 Hz Abtastrate
        final breathingOffset = 0.3 * (i % 20 < 10 ? 1.0 : -1.0);
        final sample = AccelerometerSample(
          x: 0.0,
          y: 0.0,
          z: 9.81 + breathingOffset,
          timestamp: baseTime.add(Duration(milliseconds: timeMs)),
        );

        final detected = filter.processSample(sample);
        expect(detected, isFalse,
            reason: 'Breathing triggered false positive at step $i');
      }
    });

    test(
        'Unidirectional bump (e.g. rolling over in bed without reversal) does not trigger shake',
        () {
      // Einschwingen auf Ruhelage
      for (var i = 0; i < 10; i++) {
        filter.processSample(
          AccelerometerSample(
            x: 0.0,
            y: 0.0,
            z: 9.81,
            timestamp: baseTime.add(Duration(milliseconds: i * 20)),
          ),
        );
      }

      // Einseitiger Ruck: +14 m/s^2 auf X-Achse ohne Rueckschwung
      final bumpSample = AccelerometerSample(
        x: 14.5,
        y: 0.0,
        z: 9.81,
        timestamp: baseTime.add(const Duration(milliseconds: 300)),
      );
      final detected = filter.processSample(bumpSample);
      expect(detected, isFalse,
          reason: 'Unidirectional bump should not trigger shake');
    });

    test(
        'Valid shake with peak and sign reversal within 600 ms triggers detection',
        () {
      // Einschwingen auf Ruhelage
      for (var i = 0; i < 10; i++) {
        filter.processSample(
          AccelerometerSample(
            x: 0.0,
            y: 0.0,
            z: 9.81,
            timestamp: baseTime.add(Duration(milliseconds: i * 20)),
          ),
        );
      }

      // 1. Positiver Peak: +13.5 m/s^2 bei t = 300 ms
      filter.processSample(
        AccelerometerSample(
          x: 13.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 300)),
        ),
      );

      // 2. Zwischensample bei t = 400 ms
      filter.processSample(
        AccelerometerSample(
          x: 2.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 400)),
        ),
      );

      // 3. Negativer Gegenschwung: -12.5 m/s^2 bei t = 500 ms (innerhalb 200 ms vom Peak)
      final detected = filter.processSample(
        AccelerometerSample(
          x: -12.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 500)),
        ),
      );

      expect(detected, isTrue,
          reason: 'Rapid back-and-forth shake should trigger');
    });

    test('Sign reversal exceeding 600 ms window does not trigger shake', () {
      // 1. Positiver Peak bei t = 200 ms
      filter.processSample(
        AccelerometerSample(
          x: 14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      );

      // 2. Negativer Peak erst bei t = 900 ms (> 600 ms Zeitdifferenz)
      final detected = filter.processSample(
        AccelerometerSample(
          x: -14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 900)),
        ),
      );

      expect(detected, isFalse,
          reason: 'Reversal outside 600ms window must be ignored');
    });

    test('Debounce cooldown prevents duplicate triggers within 1000 ms', () {
      // 1. Gueltiger Shake
      filter.processSample(
        AccelerometerSample(
          x: 14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      );
      final firstShake = filter.processSample(
        AccelerometerSample(
          x: -14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 400)),
        ),
      );
      expect(firstShake, isTrue);

      // 2. Nachfolgende Schuettelbewegung 300 ms spaeter waehrend Cooldown
      filter.processSample(
        AccelerometerSample(
          x: 14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 600)),
        ),
      );
      final duplicateShake = filter.processSample(
        AccelerometerSample(
          x: -14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 700)),
        ),
      );
      expect(duplicateShake, isFalse,
          reason: 'Debounce cooldown must suppress duplicates');
    });
  });

  group('AccelerometerShakeDetector Driver & Haptic Tests (TICK-016)', () {
    late FakeHapticFeedbackService fakeHaptic;
    late AccelerometerShakeDetector detector;
    final baseTime = DateTime(2026, 11, 6, 12, 0, 0);

    setUp(() {
      fakeHaptic = FakeHapticFeedbackService();
      detector = AccelerometerShakeDetector(
        filter: ShakeFilter(threshold: 12.0),
        hapticService: fakeHaptic,
      );
    });

    tearDown(() async {
      await detector.dispose();
    });

    test('Confirmed shake triggers gentle haptic feedback and emits event',
        () async {
      var callbackInvoked = false;
      detector.onShake = () => callbackInvoked = true;

      final streamEvents = <DateTime>[];
      final sub = detector.onShakeStream.listen(streamEvents.add);

      // Positiver Peak
      detector.processSample(
        AccelerometerSample(
          x: 0.0,
          y: 13.5,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 100)),
        ),
      );

      // Negativer Peak (Vorzeichenwechsel)
      final handled = detector.processSample(
        AccelerometerSample(
          x: 0.0,
          y: -12.5,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 250)),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(handled, isTrue);
      expect(callbackInvoked, isTrue);
      expect(streamEvents.length, 1);
      // Haptik-Feedback wurde genau einmal ausgeloest
      expect(fakeHaptic.triggerCount, 1);
    });

    test('startListeningWithCustomStream streams samples continuously',
        () async {
      final sampleController = StreamController<AccelerometerSample>();
      detector.startListeningWithCustomStream(sampleController.stream);

      expect(detector.isListening, isTrue);

      sampleController.add(
        AccelerometerSample(
          x: 14.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 100)),
        ),
      );
      sampleController.add(
        AccelerometerSample(
          x: -13.0,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(fakeHaptic.triggerCount, 1);

      detector.stopListening();
      expect(detector.isListening, isFalse);

      await sampleController.close();
    });
  });
}
