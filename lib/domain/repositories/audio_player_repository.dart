import 'dart:async';
import '../models/audio/audio_source_ref.dart';

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
///
/// Alle Streams dieses Repositories muessen als Broadcast-Streams bereitgestellt werden,
/// damit mehrere Schichten (z. B. UI, SleepTimer, MediaSession) gleichzeitig abonnieren koennen.
abstract class AudioPlayerRepository {
  /// Aktueller Wiedergabestatus als Multi-Subscription-Stream (Broadcast).
  Stream<AudioPlaybackStatus> get playbackStatusStream;

  /// Aktuelle Wiedergabeposition als Multi-Subscription-Stream (Broadcast).
  ///
  /// Implementierungen sollten die Ausgaberate drosseln (z. B. max. 1-2 Events/Sekunde),
  /// um unnoetige Re-Renders im Bedtime-Modus zu verhindern.
  Stream<Duration> get positionStream;

  /// Aktuelle Gesamtdauer als Multi-Subscription-Stream (Broadcast).
  Stream<Duration?> get durationStream;

  /// Aktuelle Lautstaerke (strikter Wertebereich 0.0 bis 1.0) als Multi-Subscription-Stream.
  Stream<double> get volumeStream;

  /// Initialisiert eine Audioquelle anhand eines typsicheren [AudioSourceRef].
  ///
  /// Optional kann eine initiale Startposition uebergeben werden.
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition});

  /// Startet oder setzt die Wiedergabe fort.
  Future<void> play();

  /// Pausiert die Wiedergabe.
  Future<void> pause();

  /// Stoppt die Wiedergabe und setzt die Position auf Duration.zero zurueck.
  Future<void> stop();

  /// Springt an eine bestimmte Zeitposition.
  ///
  /// Negative Werte muessen auf Duration.zero geklammert werden.
  Future<void> seek(Duration position);

  /// Setzt die Wiedergabelautstaerke.
  ///
  /// Der uebergebene Wert wird zwingend in den Wertebereich [0.0, 1.0] geklammert.
  Future<void> setVolume(double volume);

  /// Gibt belegte native Ressourcen vollstaendig frei.
  ///
  /// Dieser Aufruf muss idempotent sein (mehrfaches Aufrufen fuehrt zu keinem Fehler).
  Future<void> dispose();
}
