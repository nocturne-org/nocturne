import 'playback_position.dart';

/// Repraesentiert ein lineares oder hierarchisches Kapitel eines Audio-Mediums.
/// Speichert Start- und Endzeitpunkte millisekundengenau und unterstuetzt Unterkapitel.
class Chapter {
  /// Eindeutige ID des Kapitels.
  final String id;

  /// Titel oder Bezeichnung des Kapitels.
  final String title;

  /// Startzeitpunkt des Kapitels ab Beginn des Mediums.
  final Duration start;

  /// Endzeitpunkt des Kapitels ab Beginn des Mediums.
  final Duration end;

  /// Numerischer Index innerhalb der Kapitelliste (0-basiert).
  final int index;

  /// Optionale hierarchische Unterkapitel.
  final List<Chapter> subChapters;

  /// Erstellt ein unveraenderliches [Chapter].
  const Chapter({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.index,
    this.subChapters = const [],
  })  : assert(id.length > 0, 'Chapter id must not be empty'),
        assert(title.length > 0, 'Chapter title must not be empty'),
        assert(index >= 0, 'Chapter index must not be negative');

  /// Startzeitpunkt in Millisekunden.
  int get startMs => start.inMilliseconds;

  /// Endzeitpunkt in Millisekunden.
  int get endMs => end.inMilliseconds;

  /// Gesamtdauer des Kapitels.
  Duration get duration => end - start;

  /// Ob Start- und Endzeitpunkte logisch gueltig sind (Start vor oder gleich Ende, nicht negativ).
  bool get isValid => !start.isNegative && end >= start;

  /// Ob dieses Kapitel Unterkapitel besitzt.
  bool get hasSubChapters => subChapters.isNotEmpty;

  /// Prueft, ob eine Abspielposition innerhalb dieses Kapitels liegt.
  bool containsPosition(PlaybackPosition position) {
    return position.duration >= start && position.duration <= end;
  }

  /// Ermittelt rekursiv das tiefste aktive (Unter-)Kapitel fuer die gegebene [position].
  /// Gibt null zurueck, falls die Position nicht innerhalb dieses Kapitels liegt.
  Chapter? findActiveChapter(PlaybackPosition position) {
    if (!containsPosition(position)) {
      return null;
    }
    for (final sub in subChapters) {
      final activeSub = sub.findActiveChapter(position);
      if (activeSub != null) {
        return activeSub;
      }
    }
    return this;
  }

  /// Erzeugt eine modifizierte Kopie dieses [Chapter].
  Chapter copyWith({
    String? id,
    String? title,
    Duration? start,
    Duration? end,
    int? index,
    List<Chapter>? subChapters,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      index: index ?? this.index,
      subChapters: subChapters ?? this.subChapters,
    );
  }

  /// Serialisiert das Kapitel in eine Map inklusive Unterkapitel.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startMs': startMs,
      'endMs': endMs,
      'index': index,
      'subChapters': subChapters.map((c) => c.toMap()).toList(),
    };
  }

  /// Deserialisiert ein [Chapter] aus einer Map.
  factory Chapter.fromMap(Map<String, dynamic> map) {
    final rawSubs = map['subChapters'] as List<dynamic>? ?? const [];
    final subs = rawSubs
        .whereType<Map<String, dynamic>>()
        .map((subMap) => Chapter.fromMap(subMap))
        .toList();

    return Chapter(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      start: Duration(milliseconds: (map['startMs'] as num?)?.toInt() ?? 0),
      end: Duration(milliseconds: (map['endMs'] as num?)?.toInt() ?? 0),
      index: (map['index'] as num?)?.toInt() ?? 0,
      subChapters: List.unmodifiable(subs),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Chapter || runtimeType != other.runtimeType) return false;
    if (id != other.id ||
        title != other.title ||
        start != other.start ||
        end != other.end ||
        index != other.index ||
        subChapters.length != other.subChapters.length) {
      return false;
    }
    for (var i = 0; i < subChapters.length; i++) {
      if (subChapters[i] != other.subChapters[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        start,
        end,
        index,
        Object.hashAll(subChapters),
      );

  @override
  String toString() =>
      'Chapter(id: $id, title: "$title", $startMs-$endMs ms, subs: ${subChapters.length})';
}
