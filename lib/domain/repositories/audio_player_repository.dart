import 'dart:async';

/// Zustaende des Audio-Players.
enum AudioPlaybackStatus {
  idle,
  loading,
  buffering,
  ready,
  playing,
  paused,
  completed,
  error,
}

/// Reines Dart-Interface fuer den Audio-Player im Domain-Layer.
/// Enthaelt keinerlei Abhaengigkeiten zu Flutter oder nativen Bibliotheken.
abstract class AudioPlayerRepository {
  /// Aktueller Wiedergabestatus als Stream.
  Stream<AudioPlaybackStatus> get playbackStatusStream;

  /// Aktuelle Wiedergabeposition als Stream.
  Stream<Duration> get positionStream;

  /// Aktuelle Gesamtdauer als Stream.
  Stream<Duration?> get durationStream;

  /// Aktuelle Lautstaerke (0.0 bis 1.0) als Stream.
  Stream<double> get volumeStream;

  /// Initialisiert eine Audioquelle anhand eines URI-Strings oder lokalen Pfads.
  Future<void> setSource(String uri, {Duration? initialPosition});

  /// Startet oder setzt die Wiedergabe fort.
  Future<void> play();

  /// Pausiert die Wiedergabe.
  Future<void> pause();

  /// Stoppt die Wiedergabe und setzt Position zurueck.
  Future<void> stop();

  /// Springt an eine bestimmte Zeitposition.
  Future<void> seek(Duration position);

  /// Setzt die Wiedergabelautstaerke (0.0 bis 1.0).
  Future<void> setVolume(double volume);

  /// Gibt belegte Ressourcen vollstaendig frei.
  Future<void> dispose();
}
