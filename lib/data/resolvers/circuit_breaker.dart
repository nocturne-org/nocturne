import 'stream_models.dart';

/// Circuit-Breaker zum Schutz vor uebermaessigen Netzwerkanfragen und blockierten Endpunkten.
/// Schaltet nach 2 Fehlversuchen oder bei HTTP 403 (Bot-Check/Forbidden) sofort in den OPEN-Zustand.
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 2,
    this.resetTimeout = const Duration(seconds: 30),
  });

  /// Anzahl aufeinanderfolgender Fehler bis zur Ausloesung (Standard: 2).
  final int failureThreshold;

  /// Abklingzeit bis zum Testen einer Probe-Anfrage im HALF-OPEN Modus.
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;

  CircuitState get state {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      if (DateTime.now().difference(_lastFailureTime!) >= resetTimeout) {
        _state = CircuitState.halfOpen;
      }
    }
    return _state;
  }

  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastFailureTime => _lastFailureTime;

  /// Prueft, ob eine Anfrage an den Resolver ausgefuehrt werden darf.
  bool get canAttempt {
    final current = state;
    return current == CircuitState.closed || current == CircuitState.halfOpen;
  }

  /// Registriert einen erfolgreichen Aufruf und schliesst den Stromkreis.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _state = CircuitState.closed;
  }

  /// Registriert einen Fehler.
  /// Loest bei HTTP 403 sofort oder nach [failureThreshold] Fehlern aus.
  void recordFailure(Object error, {int? httpStatusCode}) {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();

    final isForbidden = httpStatusCode == 403 ||
        error.toString().contains('403') ||
        error.toString().toLowerCase().contains('forbidden') ||
        error.toString().toLowerCase().contains('bot-check');

    if (isForbidden || _consecutiveFailures >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// Erzwingt das manuelle Zuruecksetzen des Circuit-Breakers.
  void reset() {
    _consecutiveFailures = 0;
    _state = CircuitState.closed;
    _lastFailureTime = null;
  }
}
