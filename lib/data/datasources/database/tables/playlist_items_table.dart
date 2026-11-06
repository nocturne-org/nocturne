import 'package:drift/drift.dart';

/// Drift table definition for playlist item mappings.
class PlaylistItemsTable extends Table {
  @override
  String get tableName => 'playlist_items';

  /// Foreign key referencing the playlist ID.
  TextColumn get playlistId => text()();

  /// Foreign key referencing the media item ID.
  TextColumn get mediaItemId => text()();

  /// Timestamp when the item was added to the playlist.
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  /// Explicit sort order within the playlist.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, mediaItemId};
}
