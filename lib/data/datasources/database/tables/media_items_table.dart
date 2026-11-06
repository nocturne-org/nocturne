import 'package:drift/drift.dart';

/// Drift-Tabellendefinition fuer MediaItems (Hoerbuecher, Podcasts, YouTube-Medien).
class MediaItemsTable extends Table {
  @override
  String get tableName => 'media_items';

  /// Eindeutige ID des Mediums.
  TextColumn get id => text()();

  /// Titel des Mediums oder der Episode.
  TextColumn get title => text()();

  /// Medientyp (z. B. audiobook, podcastEpisode, youTubeAudio, youTubeVideo).
  TextColumn get type => text()();

  /// Quelltyp (z. B. localFile, safTree, streamingUrl).
  TextColumn get sourceType => text()();

  /// URI oder lokaler Dateipfad der Audioquelle.
  TextColumn get sourceUri => text()();

  /// Autor, Kuenstler oder Sprecher.
  TextColumn get author => text().nullable()();

  /// Album, Buch-Serie oder Podcast-Show.
  TextColumn get album => text().nullable()();

  /// Gesamtdauer in Millisekunden.
  IntColumn get durationMs => integer().nullable()();

  /// Pfad oder URI zum Cover-Bild.
  TextColumn get coverArtUri => text().nullable()();

  /// JSON-serialisierte Kapitelstruktur.
  TextColumn get chaptersJson => text().withDefault(const Constant('[]'))();

  /// Zuletzt gespeicherte Abspielposition in Millisekunden (exakt).
  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();

  /// Status, ob das Medium fertig gehoert wurde.
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Zeitstempel der letzten Wiedergabe.
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  /// Zusaetzliche Metadaten als JSON-String.
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();

  /// Erstellungszeitpunkt des Eintrags in der Datenbank.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Aktualisierungszeitpunkt des Eintrags.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
