/// Typensicheres Value-Object fuer die Abspielposition im Domain-Layer.
/// Kapselt Duration und Millisekunden, stellt Rechen- und Formatierungsfunktionen
/// bereit und garantiert unveraenderliche Werte (Immutable).
class PlaybackPosition implements Comparable<PlaybackPosition> {
  /// Die gekapselte Zeitdauer ab Beginn des Mediums.
  final Duration duration;

  /// Erstellt eine unveraenderliche [PlaybackPosition].
  const PlaybackPosition({required this.duration});

  /// Erstellt eine [PlaybackPosition] aus Millisekunden. Negative Werte werden auf 0 geklammert.
  factory PlaybackPosition.fromMilliseconds(int ms) {
    return PlaybackPosition(
      duration: Duration(milliseconds: ms < 0 ? 0 : ms),
    );
  }

  /// Statische Nullposition.
  static const PlaybackPosition zero = PlaybackPosition(duration: Duration.zero);

  /// Liefert die Position in Millisekunden.
  int get milliseconds => duration.inMilliseconds;

  /// Ob die Position gueltig (nicht negativ) ist.
  bool get isValid => !duration.isNegative;

  /// Addiert eine Zeitdauer und gibt eine neue [PlaybackPosition] zurueck.
  PlaybackPosition operator +(Duration other) {
    final next = duration + other;
    return PlaybackPosition(duration: next < Duration.zero ? Duration.zero : next);
  }

  /// Subtrahiert eine Zeitdauer. Ergebnis wird bei negativen Werten auf Duration.zero geklammert.
  PlaybackPosition operator -(Duration other) {
    final prev = duration - other;
    return PlaybackPosition(duration: prev < Duration.zero ? Duration.zero : prev);
  }

  /// Berechnet die Zeitdifferenz zu einer anderen [PlaybackPosition].
  Duration difference(PlaybackPosition other) => duration - other.duration;

  @override
  int compareTo(PlaybackPosition other) => duration.compareTo(other.duration);

  bool operator <(PlaybackPosition other) => duration < other.duration;
  bool operator <=(PlaybackPosition other) => duration <= other.duration;
  bool operator >(PlaybackPosition other) => duration > other.duration;
  bool operator >=(PlaybackPosition other) => duration >= other.duration;

  /// Formatiert die aktuelle Position fuer die Anzeige (z. B. "03:45" oder "01:23:45").
  String formatProgress() {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  /// Formatiert die verbleibende Restzeit bezogen auf [totalDuration] mit fuehrendem ASCII-Minus (-).
  String formatRemaining(Duration totalDuration) {
    if (totalDuration < duration) {
      return '-00:00';
    }
    final remaining = totalDuration - duration;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '-$h:$m:$s';
    }
    return '-$m:$s';
  }

  /// Berechnet den relativen Fortschritt (0.0 bis 1.0) bezogen auf [totalDuration].
  double progressFraction(Duration totalDuration) {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    final fraction = duration.inMilliseconds / totalDuration.inMilliseconds;
    if (fraction < 0.0) return 0.0;
    if (fraction > 1.0) return 1.0;
    return fraction;
  }

  /// Erzeugt eine modifizierte Kopie dieser [PlaybackPosition].
  PlaybackPosition copyWith({Duration? duration}) {
    return PlaybackPosition(duration: duration ?? this.duration);
  }

  /// Serialisiert die Position in eine Map.
  Map<String, dynamic> toMap() => {'milliseconds': milliseconds};

  /// Deserialisiert eine [PlaybackPosition] aus einer Map.
  factory PlaybackPosition.fromMap(Map<String, dynamic> map) {
    return PlaybackPosition.fromMilliseconds((map['milliseconds'] as num?)?.toInt() ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackPosition && runtimeType == other.runtimeType && duration == other.duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'PlaybackPosition(${formatProgress()})';
}
