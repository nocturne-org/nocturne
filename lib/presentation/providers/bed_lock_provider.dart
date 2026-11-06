import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier zur Steuerung der Bed-Lock Touch-Sperre (TICK-028).
class BedLockNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  /// Aktiviert die Touch-Sperre.
  void lock() {
    state = true;
  }

  /// Hebt die Touch-Sperre nach erfolgreicher Geste auf.
  void unlock() {
    state = false;
  }

  /// Schaltet den Sperrstatus um.
  void toggle() {
    state = !state;
  }
}

/// Provider fuer den Bed-Lock-Status (true = gesperrt, false = entsperrt).
final bedLockProvider = NotifierProvider<BedLockNotifier, bool>(
  BedLockNotifier.new,
);
