import 'package:drift/drift.dart';
import 'media_items_table.dart';

/// Drift-Tabellendefinition fuer Lesezeichen.
class BookmarksTable extends Table {
  @override
  String get tableName => 'bookmarks';

  /// Eindeutige Kennung des Lesezeichens.
  TextColumn get id => text()();

  /// Referenz auf das zugehoerige Medium mit kaskadierender Loeschung.
  TextColumn get mediaItemId =>
      text().references(MediaItemsTable, #id, onDelete: KeyAction.cascade)();

  /// Exakte Abspielposition in Millisekunden.
  IntColumn get positionMs => integer()();

  /// Erstellungszeitpunkt des Lesezeichens.
  DateTimeColumn get createdAt => dateTime()();

  /// Beschriftung des Lesezeichens.
  TextColumn get label => text()();

  /// Optionale Notiz des Nutzers.
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
