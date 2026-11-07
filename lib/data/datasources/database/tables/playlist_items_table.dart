import 'package:drift/drift.dart';
import 'media_items_table.dart';
import 'playlists_table.dart';

/// Drift table definition for playlist item mappings.
class PlaylistItemsTable extends Table {
  @override
  String get tableName => 'playlist_items';

  /// Foreign key referencing the playlist ID.
  TextColumn get playlistId =>
      text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();

  /// Foreign key referencing the media item ID.
  TextColumn get mediaItemId =>
      text().references(MediaItemsTable, #id, onDelete: KeyAction.cascade)();

  /// Timestamp when the item was added to the playlist.
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  /// Explicit sort order within the playlist.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, mediaItemId};
}

