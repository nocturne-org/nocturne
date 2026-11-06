import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/sensor_profile.dart';
import '../../domain/repositories/sensor_settings_repository.dart';
import '../../platform/sensors/sensor_settings_storage.dart';

/// Provider fuer das [SensorSettingsRepository].
final sensorSettingsRepositoryProvider =
    Provider<SensorSettingsRepository>((ref) {
  final storage = SensorSettingsStorage();
  ref.onDispose(() => storage.dispose());
  return storage;
});

/// Controller zur Umschaltung des aktiven Sensorprofils (Nachttisch vs. Matratze).
class SensorProfileController extends Notifier<SensorProfileConfig> {
  @override
  SensorProfileConfig build() {
    return SensorProfileConfig.nightstand;
  }

  /// Setzt ein spezifisches Profil.
  void setProfile(SensorProfileConfig profile) {
    state = profile;
    ref.read(sensorSettingsRepositoryProvider).saveActiveProfile(profile);
  }

  /// Schaltet zwischen Nachttisch- und Matratzen-Modus um.
  void toggleProfile() {
    if (state.type == SensorProfileType.nightstand) {
      setProfile(SensorProfileConfig.mattress);
    } else {
      setProfile(SensorProfileConfig.nightstand);
    }
  }
}

/// Provider fuer das aktuelle Sensor-Empfindlichkeitsprofil.
final sensorProfileProvider =
    NotifierProvider<SensorProfileController, SensorProfileConfig>(
  SensorProfileController.new,
);
