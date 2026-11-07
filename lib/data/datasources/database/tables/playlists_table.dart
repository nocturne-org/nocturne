import 'package:drift/drift.dart';

/// Drift table definition for user playlists and imported folders.
class PlaylistsTable extends Table {
  @override
  String get tableName => 'playlists';

  /// Unique identifier of the playlist.
  TextColumn get id => text()();

  /// Human-readable name of the playlist.
  TextColumn get name => text()();

  /// Kind of playlist ('user', 'custom', 'folder', 'folderImport', 'youtube', 'youtubeAuto').
  TextColumn get kind => text().withDefault(const Constant('custom'))();

  /// Source filesystem path for imported folders (null for manual playlists).
  TextColumn get sourcePath => text().nullable()();

  /// Explicit display sort order.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Timestamp when the playlist was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
