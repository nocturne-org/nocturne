import 'dart:ui';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'nocturne_audio_handler.dart';

/// Adapter fuer die Initialisierung und Konfiguration des Android MediaSessionService.
/// Gewaehrleistet unterbrechungsfreie Hintergrundwiedergabe mit WAKELOCK und Doze-Resistenz.
class MediaSessionServiceAdapter {
  /// Kanal-ID fuer die System-Benachrichtigung.
  static const String notificationChannelId = 'com.nocturne.audio.channel';

  /// Anzeigename des Benachrichtigungskanals.
  static const String notificationChannelName = 'Nocturne Bedtime Audio';

  /// Beschreibung des Benachrichtigungskanals.
  static const String notificationChannelDescription =
      'Wiedergabesteuerung und Bedtime Sleep-Timer';

  /// Initialisiert den [NocturneAudioHandler] mit MediaSession-Konfiguration.
  static Future<NocturneAudioHandler> initAudioService({
    NocturneAudioHandler? handlerOverride,
  }) async {
    if (handlerOverride != null) {
      return handlerOverride;
    }

    return await audio_service.AudioService.init(
      builder: () => NocturneAudioHandler(),
      config: const audio_service.AudioServiceConfig(
        androidNotificationChannelId: notificationChannelId,
        androidNotificationChannelName: notificationChannelName,
        androidNotificationChannelDescription: notificationChannelDescription,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        // Dienst bleibt bei Pause aktiv, damit Sleep-Timer und Bluetooth nicht abbrechen
        androidStopForegroundOnPause: false,
        notificationColor: Color(0xFF000000),
      ),
    );
  }
}
