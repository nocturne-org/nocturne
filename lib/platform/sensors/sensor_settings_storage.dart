import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/sensor_profile.dart';
import '../../domain/repositories/sensor_settings_repository.dart';

/// Implementierung von [SensorSettingsRepository] mit lokaler JSON-Persistenz
/// und reaktivem In-Memory-Broadcast (TICK-017).
class SensorSettingsStorage implements SensorSettingsRepository {
  final File? _settingsFile;
  final StreamController<SensorProfileConfig> _profileController =
      StreamController<SensorProfileConfig>.broadcast();

  SensorProfileConfig _currentProfile;

  SensorSettingsStorage({
    File? settingsFile,
    SensorProfileConfig initialProfile = SensorProfileConfig.nightstand,
  })  : _settingsFile = settingsFile,
        _currentProfile = initialProfile {
    _loadInitialSettings();
  }

  void _loadInitialSettings() {
    final file = _settingsFile;
    if (file != null && file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _currentProfile = SensorProfileConfig.fromMap(map);
      } catch (_) {
        // Bei Lesefehler auf Standard zurueckfallen
        _currentProfile = SensorProfileConfig.nightstand;
      }
    }
  }

  @override
  Future<SensorProfileConfig> getActiveProfile() async {
    return _currentProfile;
  }

  @override
  Future<void> saveActiveProfile(SensorProfileConfig profile) async {
    _currentProfile = profile;

    final file = _settingsFile;
    if (file != null) {
      try {
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        await file.writeAsString(jsonEncode(profile.toMap()));
      } catch (_) {
        // Schreibfehler isolieren
      }
    }

    if (!_profileController.isClosed) {
      _profileController.add(_currentProfile);
    }
  }

  @override
  Stream<SensorProfileConfig> watchActiveProfile() {
    return _profileController.stream;
  }

  /// Gibt belegte Streams frei.
  Future<void> dispose() async {
    await _profileController.close();
  }
}
