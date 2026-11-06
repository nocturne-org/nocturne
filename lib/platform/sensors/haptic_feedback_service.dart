import 'package:flutter/services.dart';

/// Schnittstelle fuer haptisches Feedback bei Nocturne-Sensorgesten.
abstract class HapticFeedbackService {
  /// Loest ein besonders dezentes, kurzes Vibrationsfeedback aus (ca. 15 ms).
  /// Speziell dimensioniert, um den schlafenden Bettpartner nicht zu wecken.
  Future<void> triggerGentleHaptic();
}

/// Standard-Implementierung fuer Mobilgeraete via Flutters [HapticFeedback].
class DeviceHapticFeedbackService implements HapticFeedbackService {
  const DeviceHapticFeedbackService();

  @override
  Future<void> triggerGentleHaptic() async {
    try {
      // lightImpact liefert einen kurzen, praeganten Haptik-Impuls (ca. 10-15 ms)
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Ignorieren, falls das Geraet keinen Vibrationsmotor besitzt
    }
  }
}

/// Mock-Implementierung fuer automatisierte Unit-Tests.
class FakeHapticFeedbackService implements HapticFeedbackService {
  int triggerCount = 0;

  @override
  Future<void> triggerGentleHaptic() async {
    triggerCount++;
  }

  void reset() {
    triggerCount = 0;
  }
}
