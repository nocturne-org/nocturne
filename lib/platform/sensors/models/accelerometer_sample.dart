/// Repraesentiert einen einzelnen 3-Achsen-Beschleunigungs-Messwert mit Zeitstempel.
class AccelerometerSample {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const AccelerometerSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Berechnet die euklidische Vektorlaenge (Magnitude) des Messwerts: sqrt(x^2 + y^2 + z^2).
  double get magnitude => _computeMagnitude(x, y, z);

  static double _computeMagnitude(double x, double y, double z) {
    return (x * x + y * y + z * z);
  }

  /// Berechnet die Wurzel fuer die euklidische Gesamtnorm.
  double get length {
    final magSq = magnitude;
    if (magSq <= 0.0) return 0.0;
    // Approximative oder native Wurzelfunktion
    return _sqrt(magSq);
  }

  static double _sqrt(double val) {
    if (val <= 0) return 0;
    var x = val;
    var y = 1.0;
    const e = 0.000001;
    while ((x - y).abs() > e) {
      x = (x + y) / 2;
      y = val / x;
    }
    return x;
  }

  /// Erzeugt ein Sample aus x, y, z mit aktueller Zeit.
  factory AccelerometerSample.now(double x, double y, double z) {
    return AccelerometerSample(
      x: x,
      y: y,
      z: z,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Sample(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, t: ${timestamp.toIso8601String()})';
}
