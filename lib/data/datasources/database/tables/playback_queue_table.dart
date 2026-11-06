import 'package:drift/drift.dart';
import 'media_items_table.dart';

/// Drift-Tabellendefinition fuer die persistente Abspiel-Warteschlange (Unified Queue).
class PlaybackQueueTable extends Table {
  @override
  String get tableName => 'playback_queue';

  /// Eindeutige Kennung des Queue-Eintrags.
  TextColumn get id => text()();

  /// Referenz auf das zugehoerige Medium mit kaskadierender Loeschung.
  TextColumn get mediaItemId =>
      text().references(MediaItemsTable, #id, onDelete: KeyAction.cascade)();

  /// Reihenfolge-Index in der Warteschlange fuer Reordering.
  IntColumn get sortOrder => integer()();

  /// Zeitpunkt des Hinzufuegens.
  DateTimeColumn get addedAt => dateTime()();

  /// Ob dieser Eintrag aktuell aktiv / selektiert ist.
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
