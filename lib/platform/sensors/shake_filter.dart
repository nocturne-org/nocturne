import 'models/accelerometer_sample.dart';

/// Filter- und Erkennungslogik fuer Beschleunigungssensor-Schuettelgesten (TICK-016).
///
/// 1. Software-Tiefpassfilter: Trennt die konstante Erdbeschleunigung (~9.81 m/s^2)
///    sowie niederfrequente Atembewegungen (<0.5 Hz) von dynamischen Benutzerbewegungen.
/// 2. Zeitfenster-Analyse: Erkennt Beschleunigungsspitzen mit Vorzeichenwechsel
///    innerhalb eines konfigurierbaren Zeitfensters (Standard: 600 ms).
/// 3. Debounce-Schutz: Verhindert Mehrfachausloesungen waehrend einer Schuettelbewegung.
class ShakeFilter {
  /// Standard-Glaettungsfaktor fuer den Tiefpassfilter (0.85).
  static const double defaultAlpha = 0.85;

  /// Standard-Schwellenwert fuer Spitzenbeschleunigung in m/s^2 (Nachttisch-Modus).
  static const double defaultThreshold = 12.0;

  /// Standard-Zeitfenster fuer den Vorzeichenwechsel (600 ms).
  static const Duration defaultWindowDuration = Duration(milliseconds: 600);

  /// Sperrzeit nach erfolgreicher Schuettelerkennung (1000 ms).
  static const Duration defaultCooldown = Duration(milliseconds: 1000);

  final double alpha;
  final Duration windowDuration;
  final Duration cooldownDuration;

  double _threshold;
  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 9.81;

  final List<AccelerometerSample> _recentSamples = [];
  DateTime? _lastShakeTimestamp;

  ShakeFilter({
    double threshold = defaultThreshold,
    this.alpha = defaultAlpha,
    this.windowDuration = defaultWindowDuration,
    this.cooldownDuration = defaultCooldown,
  }) : _threshold = threshold;

  /// Aktueller Schwellenwert in m/s^2.
  double get threshold => _threshold;

  set threshold(double value) {
    if (value > 0.0) {
      _threshold = value;
    }
  }

  /// Aktuell geschaetzte Gravitationskomponenten (Tiefpass).
  double get gravityX => _gravityX;
  double get gravityY => _gravityY;
  double get gravityZ => _gravityZ;

  /// Verarbeitet ein eingehendes Beschleunigungs-Sample.
  ///
  /// Gibt `true` zurueck, wenn eine gueltige Schuettelbewegung mit Vorzeichenwechsel
  /// innerhalb des 600 ms Fensters erkannt wurde.
  bool processSample(AccelerometerSample rawSample) {
    // 1. Tiefpassfilter fuer Gravitation und Atembewegungen
    _gravityX = alpha * _gravityX + (1.0 - alpha) * rawSample.x;
    _gravityY = alpha * _gravityY + (1.0 - alpha) * rawSample.y;
    _gravityZ = alpha * _gravityZ + (1.0 - alpha) * rawSample.z;

    // 2. Lineare Beschleunigung berechnen (Hochpass: Rohwert minus Gravitation)
    final linearX = rawSample.x - _gravityX;
    final linearY = rawSample.y - _gravityY;
    final linearZ = rawSample.z - _gravityZ;

    final linearSample = AccelerometerSample(
      x: linearX,
      y: linearY,
      z: linearZ,
      timestamp: rawSample.timestamp,
    );

    // 3. Debounce / Cooldown pruefen
    final lastShake = _lastShakeTimestamp;
    if (lastShake != null) {
      final elapsedSinceLastShake = rawSample.timestamp.difference(lastShake);
      if (elapsedSinceLastShake < cooldownDuration) {
        return false;
      }
    }

    // 4. Sliding Window von 600 ms pflegen
    _recentSamples.add(linearSample);
    final cutoffTime = rawSample.timestamp.subtract(windowDuration);
    _recentSamples.removeWhere((s) => s.timestamp.isBefore(cutoffTime));

    // Mindestens 2 Samples fuer eine Vorzeichenumkehr benoetigt
    if (_recentSamples.length < 2) {
      return false;
    }

    // 5. Vorzeichenwechsel und Beschleunigungsspitzen pruefen
    final isShake = _detectSignChangeAndPeak();
    if (isShake) {
      _lastShakeTimestamp = rawSample.timestamp;
      _recentSamples.clear();
      return true;
    }

    return false;
  }

  /// Analysiert das 600 ms Fenster auf Spitzenwerte und Vorzeichenwechsel.
  bool _detectSignChangeAndPeak() {
    // Pruefe jede der 3 Raumachsen unabhaengig
    final hasXShake = _axisHasSignChangeAndPeak((s) => s.x);
    final hasYShake = _axisHasSignChangeAndPeak((s) => s.y);
    final hasZShake = _axisHasSignChangeAndPeak((s) => s.z);

    return hasXShake || hasYShake || hasZShake;
  }

  bool _axisHasSignChangeAndPeak(double Function(AccelerometerSample s) axisSelector) {
    var maxPositive = 0.0;
    var minNegative = 0.0;
    var hasPositivePeak = false;
    var hasNegativePeak = false;

    // Erforderlicher Mindestwert fuer den Gegenschwung (mind. 50% des Schwellenwerts)
    final reversalThreshold = _threshold * 0.5;

    for (final sample in _recentSamples) {
      final value = axisSelector(sample);

      if (value > maxPositive) {
        maxPositive = value;
      }
      if (value < minNegative) {
        minNegative = value;
      }

      if (value >= _threshold) {
        hasPositivePeak = true;
      }
      if (value <= -_threshold) {
        hasNegativePeak = true;
      }
    }

    // Fall 1: Positiver Hauptpeak >= threshold und negativer Gegenschwung
    if (hasPositivePeak && minNegative <= -reversalThreshold) {
      return true;
    }

    // Fall 2: Negativer Hauptpeak <= -threshold und positiver Gegenschwung
    if (hasNegativePeak && maxPositive >= reversalThreshold) {
      return true;
    }

    // Fall 3: Gesamt-Spitze-zu-Spitze (Peak-to-Peak) ueberschreitet das 1.6-fache
    // bei gleichzeitigem Vorzeichenwechsel (beide Richtungen wurden durchlaufen)
    final peakToPeak = maxPositive - minNegative;
    if (peakToPeak >= _threshold * 1.6 && maxPositive > 0 && minNegative < 0) {
      return true;
    }

    return false;
  }

  /// Setzt den internen Filterstatus und Puffer zurueck.
  void reset() {
    _gravityX = 0.0;
    _gravityY = 0.0;
    _gravityZ = 9.81;
    _recentSamples.clear();
    _lastShakeTimestamp = null;
  }
}
