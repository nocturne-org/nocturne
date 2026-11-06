import 'package:drift/drift.dart';

/// Drift table definition for favorite media items (tracks, YouTube streams, audiobooks).
class FavoritesTable extends Table {
  @override
  String get tableName => 'favorites';

  /// Foreign key referencing the favorited media item ID.
  TextColumn get mediaItemId => text()();

  /// Timestamp when the item was marked as favorite.
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {mediaItemId};
}
