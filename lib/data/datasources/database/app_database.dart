import 'dart:async';
import 'package:sqlite3/sqlite3.dart';
import 'daos/media_dao.dart';
import 'tables/bookmarks_table.dart';
import 'tables/favorites_table.dart';
import 'tables/media_items_table.dart';
import 'tables/playback_history_table.dart';
import 'tables/playback_queue_table.dart';
import 'tables/playlist_items_table.dart';
import 'tables/playlists_table.dart';
import 'tables/sleep_presets_table.dart';

/// Central SQLite database for Nocturne based on sqlite3 and Drift architecture.
/// Manages table schemas for media_items, bookmarks, playback_history,
/// sleep_presets, playlists, playlist_items, favorites, and type-safe DAOs
/// with full transactional safety.
class AppDatabase {
  /// Creates a database instance with either a persistent file or ':memory:'.
  AppDatabase({
    this.name = 'nocturne_local.db',
  }) {
    if (name == ':memory:') {
      _db = sqlite3.openInMemory();
    } else {
      _db = sqlite3.open(name);
    }
    _initDatabase();
    _mediaDao = MediaDao(
      sqliteDb: _db,
      transactionRunner: transaction,
    );
  }

  /// Creates a transient in-memory database for isolated unit tests.
  factory AppDatabase.memory() {
    return AppDatabase(name: ':memory:');
  }

  /// Database file name or ':memory:'.
  final String name;

  /// Schema version of the database.
  int get schemaVersion => 1;

  late final Database _db;

  /// Underlying sqlite3 database instance.
  Database get sqliteDb => _db;

  late final MediaDao _mediaDao;

  /// DAO for media items, bookmarks, history, sleep presets, playlists, and favorites.
  MediaDao get mediaDao => _mediaDao;

  /// Drift table schema definitions for inspection and migrations.
  final MediaItemsTable mediaItemsTable = MediaItemsTable();
  final BookmarksTable bookmarksTable = BookmarksTable();
  final PlaybackHistoryTable playbackHistoryTable = PlaybackHistoryTable();
  final PlaybackQueueTable playbackQueueTable = PlaybackQueueTable();
  final SleepPresetsTable sleepPresetsTable = SleepPresetsTable();
  final PlaylistsTable playlistsTable = PlaylistsTable();
  final PlaylistItemsTable playlistItemsTable = PlaylistItemsTable();
  final FavoritesTable favoritesTable = FavoritesTable();

  void _initDatabase() {
    _db.execute('PRAGMA foreign_keys = ON;');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS media_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        sourceType TEXT NOT NULL,
        sourceUri TEXT NOT NULL,
        author TEXT,
        album TEXT,
        durationMs INTEGER,
        coverArtUri TEXT,
        chaptersJson TEXT NOT NULL DEFAULT '[]',
        lastPositionMs INTEGER NOT NULL DEFAULT 0,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        lastPlayedAt TEXT,
        metadataJson TEXT NOT NULL DEFAULT '{}',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id TEXT PRIMARY KEY,
        mediaItemId TEXT NOT NULL,
        positionMs INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        label TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (mediaItemId) REFERENCES media_items(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS idx_bookmarks_media_id ON bookmarks(mediaItemId);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS playback_history (
        id TEXT PRIMARY KEY,
        mediaItemId TEXT NOT NULL,
        playedAt TEXT NOT NULL,
        playbackDurationMs INTEGER NOT NULL,
        startPositionMs INTEGER NOT NULL,
        endPositionMs INTEGER NOT NULL,
        wasCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (mediaItemId) REFERENCES media_items(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS idx_history_media_id ON playback_history(mediaItemId);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS playback_queue (
        id TEXT PRIMARY KEY,
        mediaItemId TEXT NOT NULL,
        sortOrder INTEGER NOT NULL,
        addedAt TEXT NOT NULL,
        isCurrent INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (mediaItemId) REFERENCES media_items(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS idx_queue_sort_order ON playback_queue(sortOrder);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS sleep_presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        autoFadeOutSeconds INTEGER NOT NULL DEFAULT 60,
        shakeGracePeriodSeconds INTEGER NOT NULL DEFAULT 120,
        autoRewindSeconds INTEGER NOT NULL DEFAULT 45,
        isDefault INTEGER NOT NULL DEFAULT 0
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'custom',
        sourcePath TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_items (
        playlistId TEXT NOT NULL,
        mediaItemId TEXT NOT NULL,
        addedAt TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (playlistId, mediaItemId)
      );
      CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist_added ON playlist_items(playlistId, addedAt);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        mediaItemId TEXT PRIMARY KEY,
        addedAt TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_favorites_added ON favorites(addedAt);
    ''');
  }

  bool _inTransaction = false;

  /// Executes an action inside an atomic transaction.
  /// On any error, an automatic rollback is performed.
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_inTransaction) {
      return await action();
    }

    _inTransaction = true;
    _db.execute('BEGIN TRANSACTION;');
    try {
      final result = await action();
      _db.execute('COMMIT;');
      return result;
    } catch (e) {
      try {
        _db.execute('ROLLBACK;');
      } catch (_) {}
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  /// Closes the database and disposes underlying resources.
  Future<void> close() async {
    await _mediaDao.close();
    _db.close();
  }
}
