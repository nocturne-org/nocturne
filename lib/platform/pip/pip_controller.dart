import 'dart:async';
import 'package:flutter/services.dart';

/// Schnittstelle fuer Android Picture-in-Picture (PiP) Plattformaufrufe.
abstract class PipPlatformBridge {
  Future<bool> isPipSupported();
  Future<bool> enterPipMode({int aspectRatioNumerator = 16, int aspectRatioDenominator = 9});
  Stream<bool> get screenStateStream; // true = an, false = aus
}

/// Standard-Implementierung fuer Android via MethodChannel.
class MethodChannelPipBridge implements PipPlatformBridge {
  const MethodChannelPipBridge({
    MethodChannel channel = const MethodChannel('com.nocturne.audio/pip'),
    EventChannel screenChannel = const EventChannel('com.nocturne.audio/screen_state'),
  })  : _channel = channel,
        _screenChannel = screenChannel;

  final MethodChannel _channel;
  final EventChannel _screenChannel;

  @override
  Future<bool> isPipSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enterPipMode({
    int aspectRatioNumerator = 16,
    int aspectRatioDenominator = 9,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip', {
        'aspectRatioNumerator': aspectRatioNumerator,
        'aspectRatioDenominator': aspectRatioDenominator,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get screenStateStream {
    try {
      return _screenChannel
          .receiveBroadcastStream()
          .map((event) => event as bool);
    } catch (_) {
      return const Stream.empty();
    }
  }
}

/// Controller fuer die Steuerung des Android Picture-in-Picture Modus
/// und die Ueberwachung des Bildschirm-Status (Display Ein/Aus).
class PipController {
  PipController({
    PipPlatformBridge? platformBridge,
  }) : _bridge = platformBridge ?? const MethodChannelPipBridge();

  final PipPlatformBridge _bridge;

  final StreamController<bool> _pipStateController =
      StreamController<bool>.broadcast();

  bool _isInPipMode = false;

  /// Stream des aktuellen PiP-Status.
  Stream<bool> get pipModeStream => _pipStateController.stream;

  /// Ob sich die App aktuell im PiP-Modus befindet.
  bool get isInPipMode => _isInPipMode;

  /// Stream fuer Display-Status (true = Screen On, false = Screen Off).
  Stream<bool> get screenStateStream => _bridge.screenStateStream;

  /// Prueft, ob das Geraet Android PiP unterstuetzt.
  Future<bool> isPipSupported() => _bridge.isPipSupported();

  /// Wechselt in den Android Picture-in-Picture Modus.
  Future<bool> enterPip({int aspectNumerator = 16, int aspectDenominator = 9}) async {
    final success = await _bridge.enterPipMode(
      aspectRatioNumerator: aspectNumerator,
      aspectRatioDenominator: aspectDenominator,
    );
    if (success) {
      _isInPipMode = true;
      _pipStateController.add(true);
    }
    return success;
  }

  /// Benachrichtigt den Controller ueber das Verlassen des PiP-Modus (z. B. Rueckkehr zur Vollbild-App).
  void onPipModeExited() {
    if (_isInPipMode) {
      _isInPipMode = false;
      _pipStateController.add(false);
    }
  }

  Future<void> dispose() async {
    await _pipStateController.close();
  }
}
