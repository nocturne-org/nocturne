import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/sensor_profile.dart';
import 'package:nocturne/platform/sensors/accelerometer_shake_detector.dart';
import 'package:nocturne/platform/sensors/haptic_feedback_service.dart';
import 'package:nocturne/platform/sensors/models/accelerometer_sample.dart';
import 'package:nocturne/platform/sensors/shake_filter.dart';

void main() {
  group('Dual-Profile Acceleration Calibration Tests (TICK-017)', () {
    late ShakeFilter filter;
    final baseTime = DateTime(2026, 11, 6, 12, 0, 0);

    setUp(() {
      filter = ShakeFilter(profile: SensorProfileConfig.nightstand);
    });

    test('Nightstand Profile A (>12 m/s^2) rejects soft bed vibration (8.5 m/s^2)', () {
      // 1. Positiver Peak bei 8.5 m/s² (typische Bewegung auf Matratze)
      filter.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 100)),
        ),
      );

      // 2. Negativer Gegenschwung bei -8.5 m/s²
      final detected = filter.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 250)),
        ),
      );

      // Bei Profil A (Nachttisch 12.0) darf dieser weiche Schwung nicht ausloesen
      expect(detected, isFalse);
    });

    test('Mattress Profile B (>7.5 m/s^2) detects soft bed vibration (8.5 m/s^2)', () {
      filter.applyProfile(SensorProfileConfig.mattress);

      expect(filter.threshold, 7.5);

      // 1. Positiver Peak bei 8.5 m/s²
      filter.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 100)),
        ),
      );

      // 2. Negativer Gegenschwung bei -8.5 m/s²
      final detected = filter.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 250)),
        ),
      );

      // Bei Profil B (Matratze 7.5) muss dieser Schwung zuverlaessig ausloesen!
      expect(detected, isTrue);
    });

    test('Dynamic profile switching during active detector runtime', () {
      final fakeHaptic = FakeHapticFeedbackService();
      final detector = AccelerometerShakeDetector(
        filter: filter,
        hapticService: fakeHaptic,
      );

      // 1. Initialzustand: Nachttisch (12.0 m/s²)
      expect(detector.currentProfile.type, SensorProfileType.nightstand);

      // Weicher Schwung wird ignoriert
      detector.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 100)),
        ),
      );
      final handledInProfileA = detector.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: baseTime.add(const Duration(milliseconds: 250)),
        ),
      );
      expect(handledInProfileA, isFalse);
      expect(fakeHaptic.triggerCount, 0);

      // 2. Schnellzugriff-Umschaltung auf Matratzen-Modus (7.5 m/s²)
      detector.applyProfile(SensorProfileConfig.mattress);
      expect(detector.currentProfile.type, SensorProfileType.mattress);

      // 1500 ms spaeter (ausserhalb des Cooldowns) gleicher Schwung
      final laterTime = baseTime.add(const Duration(milliseconds: 2000));
      detector.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: laterTime.add(const Duration(milliseconds: 100)),
        ),
      );
      final handledInProfileB = detector.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: laterTime.add(const Duration(milliseconds: 250)),
        ),
      );
      expect(handledInProfileB, isTrue);
      expect(fakeHaptic.triggerCount, 1);

      // 3. Zurueck auf Nachttisch schalten
      detector.applyProfile(SensorProfileConfig.nightstand);
      expect(detector.currentProfile.type, SensorProfileType.nightstand);

      final evenLaterTime = laterTime.add(const Duration(milliseconds: 2000));
      detector.processSample(
        AccelerometerSample(
          x: 8.5,
          y: 0.0,
          z: 9.81,
          timestamp: evenLaterTime.add(const Duration(milliseconds: 100)),
        ),
      );
      final handledBackInA = detector.processSample(
        AccelerometerSample(
          x: -8.5,
          y: 0.0,
          z: 9.81,
          timestamp: evenLaterTime.add(const Duration(milliseconds: 250)),
        ),
      );
      expect(handledBackInA, isFalse);
      expect(fakeHaptic.triggerCount, 1); // Keine weitere Erhoehung
    });
  });
}
