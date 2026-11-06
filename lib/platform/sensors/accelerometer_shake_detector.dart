import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'haptic_feedback_service.dart';
import 'models/accelerometer_sample.dart';
import 'shake_filter.dart';

/// Sensortreiber fuer die Schuettelerkennung via Beschleunigungssensor (TICK-016).
///
/// Hoert auf den [accelerometerEventStream], filtert Gravitation und Atembewegungen,
/// validiert Vorzeichenwechsel innerhalb von 600 ms und loest ein dezentes
/// Haptik-Feedback zur Bestaetigung aus.
class AccelerometerShakeDetector {
  final ShakeFilter _filter;
  final HapticFeedbackService _hapticService;
  final StreamController<DateTime> _shakeEventController =
      StreamController<DateTime>.broadcast();

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  StreamSubscription<AccelerometerSample>? _customStreamSubscription;
  bool _isListening = false;

  void Function()? onShake;

  AccelerometerShakeDetector({
    ShakeFilter? filter,
    HapticFeedbackService? hapticService,
    this.onShake,
  })  : _filter = filter ?? ShakeFilter(),
        _hapticService = hapticService ?? const DeviceHapticFeedbackService();

  /// Ob der Sensor aktuell aktiv laeuft.
  bool get isListening => _isListening;

  /// Zugriff auf den zugrundeliegenden [ShakeFilter].
  ShakeFilter get filter => _filter;

  /// Broadcast-Stream aller bestaetigten Schuettel-Events.
  Stream<DateTime> get onShakeStream => _shakeEventController.stream;

  /// Startet das Auslesen des Geraete-Beschleunigungssensors.
  void startListening() {
    if (_isListening) return;

    _filter.reset();
    _isListening = true;

    _sensorSubscription = accelerometerEventStream().listen(
      (event) {
        final sample = AccelerometerSample(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        );
        _handleSample(sample);
      },
      onError: (_) {
        // Fehler im Sensortreiber abfangen
      },
      cancelOnError: false,
    );
  }

  /// Startet das Auslesen ueber einen benutzerdefinierten Stream (fuer Tests und Mocks).
  void startListeningWithCustomStream(Stream<AccelerometerSample> stream) {
    stopListening();

    _filter.reset();
    _isListening = true;

    _customStreamSubscription = stream.listen(
      _handleSample,
      cancelOnError: false,
    );
  }

  /// Verarbeitet ein einzelnes Sample direkt (fuer synchrone Vektor-Tests).
  bool processSample(AccelerometerSample sample) {
    return _handleSample(sample);
  }

  bool _handleSample(AccelerometerSample sample) {
    final isShake = _filter.processSample(sample);
    if (isShake) {
      _triggerShakeDetected(sample.timestamp);
      return true;
    }
    return false;
  }

  void _triggerShakeDetected(DateTime timestamp) {
    _hapticService.triggerGentleHaptic();

    if (!_shakeEventController.isClosed) {
      _shakeEventController.add(timestamp);
    }

    onShake?.call();
  }

  /// Beendet die Sensorbeobachtung und schont den Akku.
  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _customStreamSubscription?.cancel();
    _customStreamSubscription = null;
    _filter.reset();
    _isListening = false;
  }

  /// Gibt belegte Streams frei.
  Future<void> dispose() async {
    stopListening();
    await _shakeEventController.close();
  }
}
