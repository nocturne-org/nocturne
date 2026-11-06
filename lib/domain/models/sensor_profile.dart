/// Art des Sensor-Empfindlichkeitsprofils fuer die Schuettelerkennung (TICK-017).
enum SensorProfileType {
  /// Profil A: Feste Unterlage oder Hand (hohe Schwelle gegen Fehlalarme).
  nightstand,

  /// Profil B: Weiche Unterlage (Kissen/Matratze, sensitive Schwelle).
  mattress;

  /// Lesbare deutsche Bezeichnung.
  String get displayName {
    switch (this) {
      case SensorProfileType.nightstand:
        return 'Nachttisch / Hand';
      case SensorProfileType.mattress:
        return 'Matratze / Kissen';
    }
  }

  /// Beschreibung fuer Benutzeroberflaeche und Einstellungen.
  String get description {
    switch (this) {
      case SensorProfileType.nightstand:
        return 'Schwellenwert > 12.0 m/s². Schutz vor versehentlichen Erschuetterungen.';
      case SensorProfileType.mattress:
        return 'Schwellenwert > 7.5 m/s². Gleicht Daempfung durch Schaumstoff und Bettdecken aus.';
    }
  }
}

/// Unveraenderliche Konfiguration eines Sensor-Empfindlichkeitsprofils.
class SensorProfileConfig {
  /// Typ des Profils.
  final SensorProfileType type;

  /// Schwellenwert der Mindestbeschleunigung in m/s².
  final double threshold;

  /// Faktor fuer den Gegenschwung / Vorzeichenwechsel (Standard: 0.5 = 50%).
  final double reversalThresholdFactor;

  /// Zeitfenster fuer Vorzeichenwechsel und Spitzen (Standard: 600 ms).
  final Duration windowDuration;

  /// Sperrzeit nach erfolgreicher Erkennung (Standard: 1000 ms).
  final Duration cooldownDuration;

  const SensorProfileConfig({
    required this.type,
    required this.threshold,
    this.reversalThresholdFactor = 0.5,
    this.windowDuration = const Duration(milliseconds: 600),
    this.cooldownDuration = const Duration(milliseconds: 1000),
  })  : assert(threshold > 0.0, 'Threshold must be greater than 0'),
        assert(reversalThresholdFactor > 0.0 && reversalThresholdFactor <= 1.0,
            'Reversal factor must be in (0.0, 1.0]');

  /// Standard-Profil A: Nachttisch / Hand (12.0 m/s²).
  static const SensorProfileConfig nightstand = SensorProfileConfig(
    type: SensorProfileType.nightstand,
    threshold: 12.0,
    reversalThresholdFactor: 0.5,
    windowDuration: Duration(milliseconds: 600),
    cooldownDuration: Duration(milliseconds: 1000),
  );

  /// Standard-Profil B: Matratze / Kissen (7.5 m/s²).
  static const SensorProfileConfig mattress = SensorProfileConfig(
    type: SensorProfileType.mattress,
    threshold: 7.5,
    reversalThresholdFactor: 0.5,
    windowDuration: Duration(milliseconds: 600),
    cooldownDuration: Duration(milliseconds: 1000),
  );

  /// Erforderlicher Mindestwert fuer den Gegenschwung.
  double get reversalThreshold => threshold * reversalThresholdFactor;

  /// Anzeige-Name des Profils.
  String get displayName => type.displayName;

  /// Beschreibung des Profils.
  String get description => type.description;

  /// Erzeugt eine modifizierte Kopie dieses Profils.
  SensorProfileConfig copyWith({
    SensorProfileType? type,
    double? threshold,
    double? reversalThresholdFactor,
    Duration? windowDuration,
    Duration? cooldownDuration,
  }) {
    return SensorProfileConfig(
      type: type ?? this.type,
      threshold: threshold ?? this.threshold,
      reversalThresholdFactor:
          reversalThresholdFactor ?? this.reversalThresholdFactor,
      windowDuration: windowDuration ?? this.windowDuration,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
    );
  }

  /// Serialisiert das Profil zur persistenten Speicherung in Einstellungen.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'threshold': threshold,
      'reversalThresholdFactor': reversalThresholdFactor,
      'windowDurationMs': windowDuration.inMilliseconds,
      'cooldownDurationMs': cooldownDuration.inMilliseconds,
    };
  }

  /// Deserialisiert das Profil aus einer Map mit Fallback auf [nightstand].
  factory SensorProfileConfig.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String?;
    final type = SensorProfileType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => SensorProfileType.nightstand,
    );

    final defaultForType = type == SensorProfileType.mattress ? mattress : nightstand;

    return SensorProfileConfig(
      type: type,
      threshold: (map['threshold'] as num?)?.toDouble() ?? defaultForType.threshold,
      reversalThresholdFactor: (map['reversalThresholdFactor'] as num?)?.toDouble() ??
          defaultForType.reversalThresholdFactor,
      windowDuration: map['windowDurationMs'] != null
          ? Duration(milliseconds: (map['windowDurationMs'] as num).toInt())
          : defaultForType.windowDuration,
      cooldownDuration: map['cooldownDurationMs'] != null
          ? Duration(milliseconds: (map['cooldownDurationMs'] as num).toInt())
          : defaultForType.cooldownDuration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorProfileConfig &&
          type == other.type &&
          threshold == other.threshold &&
          reversalThresholdFactor == other.reversalThresholdFactor &&
          windowDuration == other.windowDuration &&
          cooldownDuration == other.cooldownDuration;

  @override
  int get hashCode => Object.hash(
        type,
        threshold,
        reversalThresholdFactor,
        windowDuration,
        cooldownDuration,
      );

  @override
  String toString() =>
      'SensorProfileConfig(${type.name}, threshold: ${threshold.toStringAsFixed(1)} m/s²)';
}
