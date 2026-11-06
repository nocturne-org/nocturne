import 'dart:async';
import '../models/sensor_profile.dart';

/// Schnittstelle zur persistenten Verwaltung der Sensoreinstellungen und -profile (TICK-017).
///
/// Reines Dart im Domain-Layer ohne Framework-Abhaengigkeiten.
abstract class SensorSettingsRepository {
  /// Laedt das aktuell aktive Sensorprofil asynchron.
  Future<SensorProfileConfig> getActiveProfile();

  /// Speichert das aktive Sensorprofil persistent.
  Future<void> saveActiveProfile(SensorProfileConfig profile);

  /// Beobachtet Aenderungen am aktiven Sensorprofil reaktiv als Broadcast-Stream.
  Stream<SensorProfileConfig> watchActiveProfile();
}
