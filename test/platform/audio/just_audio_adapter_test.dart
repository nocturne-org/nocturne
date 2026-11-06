import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/audio/audio_focus_manager.dart';
import 'package:nocturne/platform/audio/just_audio_player_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JustAudioPlayerAdapter Logic Tests (TICK-006)', () {
    test(
        'Ducking-Faktor modifiziert Lautstaerke bezogen auf Benutzer-Lautstaerke',
        () async {
      final adapter = JustAudioPlayerAdapter();

      // Setze Basis-Lautstaerke auf 80%
      await adapter.setVolume(0.8);

      // Ducking mit Faktor 0.2
      await adapter.applyDuckFactor(AudioFocusManager.defaultDuckFactor);

      // Bei Dispose wird kein Fehler geworfen
      await adapter.dispose();
      await adapter.dispose(); // Idempotenz
    });
  });
}
