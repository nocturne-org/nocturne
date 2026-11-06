import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/sensor_profile.dart';
import 'package:nocturne/platform/sensors/sensor_settings_storage.dart';

void main() {
  group('SensorProfileConfig Domain Model Tests (TICK-017)', () {
    test('nightstand profile is configured with 12.0 m/s^2 threshold', () {
      const config = SensorProfileConfig.nightstand;
      expect(config.type, SensorProfileType.nightstand);
      expect(config.threshold, 12.0);
      expect(config.reversalThresholdFactor, 0.5);
      expect(config.reversalThreshold, 6.0);
      expect(config.windowDuration, const Duration(milliseconds: 600));
      expect(config.displayName, contains('Nachttisch'));
    });

    test('mattress profile is configured with sensitive 7.5 m/s^2 threshold', () {
      const config = SensorProfileConfig.mattress;
      expect(config.type, SensorProfileType.mattress);
      expect(config.threshold, 7.5);
      expect(config.reversalThresholdFactor, 0.5);
      expect(config.reversalThreshold, 3.75);
      expect(config.windowDuration, const Duration(milliseconds: 600));
      expect(config.displayName, contains('Matratze'));
    });

    test('toMap and fromMap are symmetrical and lossless', () {
      const original = SensorProfileConfig.mattress;
      final map = original.toMap();
      final restored = SensorProfileConfig.fromMap(map);

      expect(restored, equals(original));
      expect(restored.type, SensorProfileType.mattress);
      expect(restored.threshold, 7.5);
      expect(restored.windowDuration, const Duration(milliseconds: 600));
    });

    test('fromMap falls back gracefully on missing or invalid data', () {
      final restored = SensorProfileConfig.fromMap(const {});
      expect(restored.type, SensorProfileType.nightstand);
      expect(restored.threshold, 12.0);
    });
  });

  group('SensorSettingsStorage Persistence Tests (TICK-017)', () {
    late Directory tempDir;
    late File tempFile;
    late SensorSettingsStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sensor_settings_test_');
      tempFile = File('${tempDir.path}/sensor_settings.json');
      storage = SensorSettingsStorage(settingsFile: tempFile);
    });

    tearDown(() async {
      await storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Default profile is nightstand and saves to file on change', () async {
      final initial = await storage.getActiveProfile();
      expect(initial.type, SensorProfileType.nightstand);

      // Wechsel zu Matratzen-Modus
      await storage.saveActiveProfile(SensorProfileConfig.mattress);

      final updated = await storage.getActiveProfile();
      expect(updated.type, SensorProfileType.mattress);
      expect(updated.threshold, 7.5);

      // Datei wurde auf der Festplatte persistiert
      expect(tempFile.existsSync(), isTrue);

      // Zweite Storage-Instanz laedt die gespeicherten Einstellungen
      final secondStorage = SensorSettingsStorage(settingsFile: tempFile);
      final persisted = await secondStorage.getActiveProfile();
      expect(persisted.type, SensorProfileType.mattress);
      expect(persisted.threshold, 7.5);
      await secondStorage.dispose();
    });

    test('watchActiveProfile emits updates reactively', () async {
      final profiles = <SensorProfileType>[];
      final sub = storage.watchActiveProfile().listen((p) => profiles.add(p.type));

      await storage.saveActiveProfile(SensorProfileConfig.mattress);
      await storage.saveActiveProfile(SensorProfileConfig.nightstand);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(profiles, [
        SensorProfileType.mattress,
        SensorProfileType.nightstand,
      ]);
    });
  });
}
