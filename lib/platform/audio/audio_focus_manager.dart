import 'dart:async';
import 'package:audio_session/audio_session.dart';

/// Behandelt AudioFocus-Ereignisse gemaess Android Media- und Bedtime-Spezifikation:
/// - Ducking bei Navigations- oder Systemhinweistoenen
/// - Pause bei Anrufen oder permanentem Fokusverlust
/// - Sofortige Pause bei Trennung der Kopfhoerer (Becoming Noisy)
class AudioFocusManager {
  /// Lautstaerke-Absenkungsfaktor bei transientem Ducking (20% der Maximallautstaerke).
  static const double defaultDuckFactor = 0.2;

  final AudioSession? _session;
  final double duckFactor;

  /// Callback bei erzwungenem Pausieren (z. B. Anruf, Kopfhoerer abgezogen).
  final Future<void> Function()? onPauseRequested;

  /// Callback zur Lautstaerkeanpassung bei Ducking / Ducking-Ende.
  final Future<void> Function(double factor)? onVolumeDuckRequested;

  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  bool _isDucked = false;

  AudioFocusManager({
    AudioSession? session,
    this.duckFactor = defaultDuckFactor,
    this.onPauseRequested,
    this.onVolumeDuckRequested,
  }) : _session = session;

  /// Initialisiert die AudioSession mit Sprach- und Medien-Optimierung (AUDIOFOCUS_GAIN).
  Future<void> initialize() async {
    final session = _session ?? await AudioSession.instance;

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    _interruptionSub = session.interruptionEventStream.listen(handleInterruption);
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) => handleBecomingNoisy());
  }

  /// Verarbeitet externe AudioFocus-Unterbrechungen.
  Future<void> handleInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _isDucked = true;
          if (onVolumeDuckRequested != null) {
            await onVolumeDuckRequested!(duckFactor);
          }
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (onPauseRequested != null) {
            await onPauseRequested!();
          }
          break;
      }
    } else {
      // Unterbrechung beendet
      if (_isDucked) {
        _isDucked = false;
        if (onVolumeDuckRequested != null) {
          await onVolumeDuckRequested!(1.0);
        }
      }
    }
  }

  /// Verarbeitet das Abziehen von Kopfhoerern oder Bluetooth-Trennung (Becoming Noisy).
  /// Verhindert, dass das Audio im Schlafzimmer ploetzlich laut ueber Lautsprecher ertoent.
  Future<void> handleBecomingNoisy() async {
    if (onPauseRequested != null) {
      await onPauseRequested!();
    }
  }

  /// Gibt belegte Streams frei.
  Future<void> dispose() async {
    await _interruptionSub?.cancel();
    await _becomingNoisySub?.cancel();
  }
}
