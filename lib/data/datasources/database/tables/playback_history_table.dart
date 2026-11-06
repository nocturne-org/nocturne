import 'package:drift/drift.dart';
import 'media_items_table.dart';

/// Drift-Tabellendefinition fuer die Wiedergabe-Historie.
class PlaybackHistoryTable extends Table {
  @override
  String get tableName => 'playback_history';

  /// Eindeutige Kennung des Historien-Eintrags.
  TextColumn get id => text()();

  /// Referenz auf das zugehoerige Medium mit kaskadierender Loeschung.
  TextColumn get mediaItemId =>
      text().references(MediaItemsTable, #id, onDelete: KeyAction.cascade)();

  /// Zeitpunkt der Wiedergabesitzung.
  DateTimeColumn get playedAt => dateTime()();

  /// Gehoerte Dauer in Millisekunden waehrend dieser Sitzung.
  IntColumn get playbackDurationMs => integer()();

  /// Startposition in Millisekunden.
  IntColumn get startPositionMs => integer()();

  /// Endposition in Millisekunden.
  IntColumn get endPositionMs => integer()();

  /// Ob das Medium in dieser Sitzung beendet wurde.
  BoolColumn get wasCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
