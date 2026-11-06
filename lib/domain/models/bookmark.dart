import 'playback_position.dart';

/// Repraesentiert ein benutzerdefiniertes oder automatisiertes Lesezeichen (z. B. Sleep-Rewind).
/// Speichert die exakte Position, Erstellungszeitpunkt, Label und optionale Notiz.
class Bookmark {
  /// Eindeutige Kennung des Lesezeichens.
  final String id;

  /// ID des zugeordneten Mediums.
  final String mediaItemId;

  /// Exakte Abspielposition des Lesezeichens.
  final PlaybackPosition position;

  /// Erstellungszeitpunkt im UTC- oder lokalen ISO-8601-Format.
  final DateTime createdAt;

  /// Bezeichnung oder Titel des Lesezeichens (z. B. "Vor dem Einschlafen").
  final String label;

  /// Optionale ausfuehrliche Notiz des Hoerers.
  final String? note;

  /// Erstellt ein [Bookmark].
  const Bookmark({
    required this.id,
    required this.mediaItemId,
    required this.position,
    required this.createdAt,
    required this.label,
    this.note,
  })  : assert(id.length > 0, 'Bookmark id must not be empty'),
        assert(
            mediaItemId.length > 0, 'Bookmark mediaItemId must not be empty');

  /// Liefert die Position in Millisekunden fuer einfache Datenbank-Indizierung.
  int get positionMs => position.milliseconds;

  /// Erzeugt eine modifizierte Kopie dieses [Bookmark].
  Bookmark copyWith({
    String? id,
    String? mediaItemId,
    PlaybackPosition? position,
    DateTime? createdAt,
    String? label,
    String? note,
  }) {
    return Bookmark(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      label: label ?? this.label,
      note: note ?? this.note,
    );
  }

  /// Serialisiert das Lesezeichen in eine Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mediaItemId': mediaItemId,
      'positionMs': positionMs,
      'createdAt': createdAt.toIso8601String(),
      'label': label,
      'note': note,
    };
  }

  /// Deserialisiert ein [Bookmark] aus einer Map.
  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String? ?? '',
      mediaItemId: map['mediaItemId'] as String? ?? '',
      position: PlaybackPosition.fromMilliseconds(
        (map['positionMs'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      label: map['label'] as String? ?? '',
      note: map['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          mediaItemId == other.mediaItemId &&
          position == other.position &&
          createdAt == other.createdAt &&
          label == other.label &&
          note == other.note;

  @override
  int get hashCode =>
      Object.hash(id, mediaItemId, position, createdAt, label, note);

  @override
  String toString() =>
      'Bookmark(id: $id, mediaId: $mediaItemId, pos: ${position.formatProgress()}, label: "$label")';
}
