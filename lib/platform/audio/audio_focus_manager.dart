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
  bool _isFocusActive = false;

  AudioFocusManager({
    AudioSession? session,
    this.duckFactor = defaultDuckFactor,
    this.onPauseRequested,
    this.onVolumeDuckRequested,
  }) : _session = session;

  /// Ob der Audiofokus aktuell aktiv gehalten wird.
  bool get isFocusActive => _isFocusActive;

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

  /// Fordert den Audiofokus aktiv an.
  Future<bool> activateFocus() async {
    final session = _session ?? await AudioSession.instance;
    final granted = await session.setActive(true);
    _isFocusActive = granted;
    return granted;
  }

  /// Gibt den Audiofokus vollstaendig frei (Bluetooth Auto-Disconnect, TICK-018).
  ///
  /// Wird nach Ablauf der Grace-Period aufgerufen, damit verbundene
  /// Bluetooth-Kopfhoerer erkennen, dass kein Audio mehr aktiv ist,
  /// und selbststaendig in den Standby-/Energiesparmodus wechseln.
  Future<void> abandonFocus() async {
    try {
      final session = _session ?? await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {
      // Ignorieren falls die Session bereits inaktiv ist oder in Testumgebung ohne Plattform-Channel
    }
    _isFocusActive = false;
    _isDucked = false;
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
