import 'dart:async';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import '../../../../domain/models/audio/audio_source_ref.dart';
import '../../../../domain/models/bookmark.dart';
import '../../../../domain/models/chapter.dart';
import '../../../../domain/models/media_item.dart';
import '../../../../domain/models/playback_position.dart';

/// Data entity for a playback history record.
class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.id,
    required this.mediaItemId,
    required this.playedAt,
    required this.playbackDurationMs,
    required this.startPositionMs,
    required this.endPositionMs,
    this.wasCompleted = false,
  });

  final String id;
  final String mediaItemId;
  final DateTime playedAt;
  final int playbackDurationMs;
  final int startPositionMs;
  final int endPositionMs;
  final bool wasCompleted;

  PlaybackHistoryEntry copyWith({
    String? id,
    String? mediaItemId,
    DateTime? playedAt,
    int? playbackDurationMs,
    int? startPositionMs,
    int? endPositionMs,
    bool? wasCompleted,
  }) {
    return PlaybackHistoryEntry(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      playedAt: playedAt ?? this.playedAt,
      playbackDurationMs: playbackDurationMs ?? this.playbackDurationMs,
      startPositionMs: startPositionMs ?? this.startPositionMs,
      endPositionMs: endPositionMs ?? this.endPositionMs,
      wasCompleted: wasCompleted ?? this.wasCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'mediaItemId': mediaItemId,
        'playedAt': playedAt.toIso8601String(),
        'playbackDurationMs': playbackDurationMs,
        'startPositionMs': startPositionMs,
        'endPositionMs': endPositionMs,
        'wasCompleted': wasCompleted,
      };

  factory PlaybackHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PlaybackHistoryEntry(
      id: map['id'] as String? ?? '',
      mediaItemId: map['mediaItemId'] as String? ?? '',
      playedAt:
          DateTime.tryParse(map['playedAt'] as String? ?? '') ?? DateTime.now(),
      playbackDurationMs: (map['playbackDurationMs'] as num?)?.toInt() ?? 0,
      startPositionMs: (map['startPositionMs'] as num?)?.toInt() ?? 0,
      endPositionMs: (map['endPositionMs'] as num?)?.toInt() ?? 0,
      wasCompleted: map['wasCompleted'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          mediaItemId == other.mediaItemId &&
          startPositionMs == other.startPositionMs &&
          endPositionMs == other.endPositionMs;

  @override
  int get hashCode =>
      Object.hash(id, mediaItemId, startPositionMs, endPositionMs);
}

/// Data entity for a sleep timer preset configuration.
class SleepPresetEntry {
  const SleepPresetEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.autoFadeOutSeconds = 60,
    this.shakeGracePeriodSeconds = 120,
    this.autoRewindSeconds = 45,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final int autoFadeOutSeconds;
  final int shakeGracePeriodSeconds;
  final int autoRewindSeconds;
  final bool isDefault;

  SleepPresetEntry copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    int? autoFadeOutSeconds,
    int? shakeGracePeriodSeconds,
    int? autoRewindSeconds,
    bool? isDefault,
  }) {
    return SleepPresetEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      autoFadeOutSeconds: autoFadeOutSeconds ?? this.autoFadeOutSeconds,
      shakeGracePeriodSeconds:
          shakeGracePeriodSeconds ?? this.shakeGracePeriodSeconds,
      autoRewindSeconds: autoRewindSeconds ?? this.autoRewindSeconds,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'autoFadeOutSeconds': autoFadeOutSeconds,
        'shakeGracePeriodSeconds': shakeGracePeriodSeconds,
        'autoRewindSeconds': autoRewindSeconds,
        'isDefault': isDefault,
      };

  factory SleepPresetEntry.fromMap(Map<String, dynamic> map) {
    return SleepPresetEntry(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      autoFadeOutSeconds: (map['autoFadeOutSeconds'] as num?)?.toInt() ?? 60,
      shakeGracePeriodSeconds:
          (map['shakeGracePeriodSeconds'] as num?)?.toInt() ?? 120,
      autoRewindSeconds: (map['autoRewindSeconds'] as num?)?.toInt() ?? 45,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepPresetEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          durationMinutes == other.durationMinutes;

  @override
  int get hashCode => Object.hash(id, name, durationMinutes);
}

/// Data entity for a persistent playback queue item.
class PlaybackQueueEntry {
  const PlaybackQueueEntry({
    required this.id,
    required this.mediaItemId,
    required this.sortOrder,
    required this.addedAt,
    this.isCurrent = false,
  });

  final String id;
  final String mediaItemId;
  final int sortOrder;
  final DateTime addedAt;
  final bool isCurrent;

  PlaybackQueueEntry copyWith({
    String? id,
    String? mediaItemId,
    int? sortOrder,
    DateTime? addedAt,
    bool? isCurrent,
  }) {
    return PlaybackQueueEntry(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

/// Data entity for a user playlist or imported folder.
class PlaylistEntry {
  const PlaylistEntry({
    required this.id,
    required this.name,
    this.kind = 'custom',
    this.sourcePath,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String kind;
  final String? sourcePath;
  final int sortOrder;
  final DateTime createdAt;

  PlaylistEntry copyWith({
    String? id,
    String? name,
    String? kind,
    String? sourcePath,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return PlaylistEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sourcePath: sourcePath ?? this.sourcePath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Data entity mapping an item to a playlist.
class PlaylistItemEntry {
  const PlaylistItemEntry({
    required this.playlistId,
    required this.mediaItemId,
    required this.addedAt,
    this.sortOrder = 0,
  });

  final String playlistId;
  final String mediaItemId;
  final DateTime addedAt;
  final int sortOrder;
}

/// Data entity for a favorite item.
class FavoriteEntry {
  const FavoriteEntry({
    required this.mediaItemId,
    required this.addedAt,
  });

  final String mediaItemId;
  final DateTime addedAt;
}

/// Type-safe Data Access Object (DAO) for Media, Bookmarks, History,
/// Sleep Presets, Playlists, and Favorites backed by SQLite.
class MediaDao {
  MediaDao({
    Database? sqliteDb,
    Future<T> Function<T>(Future<T> Function() action)? transactionRunner,
  })  : _db = sqliteDb ?? sqlite3.openInMemory(),
        _transactionRunner = transactionRunner;

  final Database _db;
  final Future<T> Function<T>(Future<T> Function() action)? _transactionRunner;

  /// Executes an action inside an atomic transaction.
  Future<T> transaction<T>(Future<T> Function() action) async {
    final runner = _transactionRunner;
    if (runner != null) {
      return await runner(action);
    }
    return await action();
  }

  final StreamController<List<MediaItem>> _mediaListController =
      StreamController<List<MediaItem>>.broadcast();
  final Map<String, StreamController<MediaItem?>> _singleMediaControllers = {};
  final Map<String, StreamController<List<Bookmark>>>
      _mediaBookmarkControllers = {};
  final StreamController<List<String>> _queueController =
      StreamController<List<String>>.broadcast();
  final StreamController<List<PlaylistEntry>> _playlistsController =
      StreamController<List<PlaylistEntry>>.broadcast();
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  // ==================== ROW MAPPING HELPERS ====================

  MediaItem _rowToMediaItem(Row row) {
    final chaptersJson = row['chaptersJson'] as String? ?? '[]';
    List<Chapter> chapters = const [];
    try {
      final decoded = jsonDecode(chaptersJson) as List<dynamic>;
      chapters = decoded
          .map((e) => Chapter.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    final metadataJson = row['metadataJson'] as String? ?? '{}';
    Map<String, dynamic> metadata = const {};
    try {
      metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
    } catch (_) {}

    final typeName = row['type'] as String? ?? 'audiobook';
    final type = MediaType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MediaType.audiobook,
    );

    final sourceTypeName = row['sourceType'] as String? ?? 'file';
    final sourceUri = row['sourceUri'] as String? ?? '';
    final sourceType = AudioSourceType.values.firstWhere(
      (e) => e.name == sourceTypeName,
      orElse: () => AudioSourceType.file,
    );

    final author = row['author'] as String?;
    final album = row['album'] as String?;
    final durationMs = (row['durationMs'] as num?)?.toInt();
    final coverArtUri = row['coverArtUri'] as String?;
    final lastPosMs = (row['lastPositionMs'] as num?)?.toInt() ?? 0;
    final isCompleted = (row['isCompleted'] as num?)?.toInt() == 1;
    final lastPlayedAtStr = row['lastPlayedAt'] as String?;

    AudioSourceRef source;
    if (metadata.containsKey('source') && metadata['source'] is Map) {
      try {
        source = AudioSourceRef.fromMap(
            metadata['source'] as Map<String, dynamic>);
      } catch (_) {
        source = AudioSourceRef(
          uri: sourceUri,
          type: sourceType,
          title: row['title'] as String?,
          artist: author,
        );
      }
    } else {
      source = AudioSourceRef(
        uri: sourceUri,
        type: sourceType,
        title: row['title'] as String?,
        artist: author,
      );
    }

    return MediaItem(
      id: row['id'] as String,
      title: row['title'] as String,
      type: type,
      source: source,
      author: author,
      album: album,
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      coverArtUri: coverArtUri,
      chapters: chapters,
      lastPosition: PlaybackPosition.fromMilliseconds(lastPosMs),
      isCompleted: isCompleted,
      lastPlayedAt:
          lastPlayedAtStr != null ? DateTime.tryParse(lastPlayedAtStr) : null,
      metadata: metadata,
    );
  }

  Bookmark _rowToBookmark(Row row) {
    final createdAtStr = row['createdAt'] as String? ?? '';
    return Bookmark(
      id: row['id'] as String,
      mediaItemId: row['mediaItemId'] as String,
      position: PlaybackPosition.fromMilliseconds(
        (row['positionMs'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.tryParse(createdAtStr) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      label: row['label'] as String? ?? '',
      note: row['note'] as String?,
    );
  }

  PlaybackHistoryEntry _rowToHistory(Row row) {
    return PlaybackHistoryEntry(
      id: row['id'] as String,
      mediaItemId: row['mediaItemId'] as String,
      playedAt: DateTime.tryParse(row['playedAt'] as String? ?? '') ??
          DateTime.now(),
      playbackDurationMs: (row['playbackDurationMs'] as num?)?.toInt() ?? 0,
      startPositionMs: (row['startPositionMs'] as num?)?.toInt() ?? 0,
      endPositionMs: (row['endPositionMs'] as num?)?.toInt() ?? 0,
      wasCompleted: (row['wasCompleted'] as num?)?.toInt() == 1,
    );
  }

  SleepPresetEntry _rowToPreset(Row row) {
    return SleepPresetEntry(
      id: row['id'] as String,
      name: row['name'] as String,
      durationMinutes: (row['durationMinutes'] as num?)?.toInt() ?? 30,
      autoFadeOutSeconds: (row['autoFadeOutSeconds'] as num?)?.toInt() ?? 60,
      shakeGracePeriodSeconds:
          (row['shakeGracePeriodSeconds'] as num?)?.toInt() ?? 120,
      autoRewindSeconds: (row['autoRewindSeconds'] as num?)?.toInt() ?? 45,
      isDefault: (row['isDefault'] as num?)?.toInt() == 1,
    );
  }

  PlaylistEntry _rowToPlaylist(Row row) {
    return PlaylistEntry(
      id: row['id'] as String,
      name: row['name'] as String,
      kind: row['kind'] as String? ?? 'custom',
      sourcePath: row['sourcePath'] as String?,
      sortOrder: (row['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ==================== NOTIFICATION HELPERS ====================

  void _notifyMediaChanged([String? specificId]) async {
    final list = await getAllMediaItems();
    if (!_mediaListController.isClosed) {
      _mediaListController.add(list);
    }

    if (specificId != null) {
      final ctrl = _singleMediaControllers[specificId];
      if (ctrl != null && !ctrl.isClosed) {
        final item = await getMediaItemById(specificId);
        ctrl.add(item);
      }
    } else {
      for (final entry in _singleMediaControllers.entries) {
        if (!entry.value.isClosed) {
          final item = await getMediaItemById(entry.key);
          entry.value.add(item);
        }
      }
    }
  }

  void _notifyBookmarksChanged(String mediaItemId) async {
    final ctrl = _mediaBookmarkControllers[mediaItemId];
    if (ctrl != null && !ctrl.isClosed) {
      final list = await getBookmarksForMedia(mediaItemId);
      ctrl.add(list);
    }
  }

  void _notifyPlaylistsChanged() async {
    if (!_playlistsController.isClosed) {
      final list = await getPlaylistsSortedByRecent();
      _playlistsController.add(list);
    }
  }

  void _notifyFavoritesChanged() async {
    if (!_favoritesController.isClosed) {
      final favList = await getFavorites();
      _favoritesController.add(favList.toSet());
    }
  }

  void _notifyQueueChanged() async {
    if (!_queueController.isClosed) {
      final queue = await getPlaybackQueue();
      _queueController.add(queue);
    }
  }

  // ==================== MEDIA ITEMS ====================

  /// Watch all media items reactively.
  Stream<List<MediaItem>> watchAllMediaItems() async* {
    yield await getAllMediaItems();
    yield* _mediaListController.stream;
  }

  /// Watch a single media item by its ID.
  Stream<MediaItem?> watchMediaItemById(String id) async* {
    yield await getMediaItemById(id);
    final ctrl = _singleMediaControllers.putIfAbsent(
      id,
      () => StreamController<MediaItem?>.broadcast(),
    );
    yield* ctrl.stream;
  }

  /// Retrieves all stored media items.
  Future<List<MediaItem>> getAllMediaItems() async {
    final rows = _db.select('SELECT * FROM media_items;');
    return rows.map(_rowToMediaItem).toList();
  }

  /// Retrieves a single media item by its ID.
  Future<MediaItem?> getMediaItemById(String id) async {
    final rows = _db.select('SELECT * FROM media_items WHERE id = ?;', [id]);
    if (rows.isEmpty) return null;
    return _rowToMediaItem(rows.first);
  }

  /// Inserts a new media item into the database.
  Future<void> insertMediaItem(MediaItem item) async {
    final chaptersJson =
        jsonEncode(item.chapters.map((c) => c.toMap()).toList());
    final metadataMap = Map<String, dynamic>.from(item.metadata);
    metadataMap['source'] = item.source.toMap();
    final metadataJson = jsonEncode(metadataMap);
    final now = DateTime.now().toIso8601String();

    _db.execute(
      '''
      INSERT INTO media_items (
        id, title, type, sourceType, sourceUri, author, album, durationMs,
        coverArtUri, chaptersJson, lastPositionMs, isCompleted, lastPlayedAt,
        metadataJson, createdAt, updatedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        item.id,
        item.title,
        item.type.name,
        item.source.type.name,
        item.source.uri,
        item.author,
        item.album,
        item.durationMs,
        item.coverArtUri,
        chaptersJson,
        item.lastPosition.milliseconds,
        item.isCompleted ? 1 : 0,
        item.lastPlayedAt?.toIso8601String(),
        metadataJson,
        now,
        now,
      ],
    );
    _notifyMediaChanged(item.id);
  }

  /// Updates an existing media item in the database.
  Future<void> updateMediaItem(MediaItem item) async {
    final chaptersJson =
        jsonEncode(item.chapters.map((c) => c.toMap()).toList());
    final metadataMap = Map<String, dynamic>.from(item.metadata);
    metadataMap['source'] = item.source.toMap();
    final metadataJson = jsonEncode(metadataMap);
    final now = DateTime.now().toIso8601String();

    _db.execute(
      '''
      UPDATE media_items SET
        title = ?, type = ?, sourceType = ?, sourceUri = ?, author = ?, album = ?,
        durationMs = ?, coverArtUri = ?, chaptersJson = ?, lastPositionMs = ?,
        isCompleted = ?, lastPlayedAt = ?, metadataJson = ?, updatedAt = ?
      WHERE id = ?;
      ''',
      [
        item.title,
        item.type.name,
        item.source.type.name,
        item.source.uri,
        item.author,
        item.album,
        item.durationMs,
        item.coverArtUri,
        chaptersJson,
        item.lastPosition.milliseconds,
        item.isCompleted ? 1 : 0,
        item.lastPlayedAt?.toIso8601String(),
        metadataJson,
        now,
        item.id,
      ],
    );
    _notifyMediaChanged(item.id);
  }

  /// Inserts or updates a media item (upsert).
  Future<void> upsertMediaItem(MediaItem item) async {
    final chaptersJson =
        jsonEncode(item.chapters.map((c) => c.toMap()).toList());
    final metadataMap = Map<String, dynamic>.from(item.metadata);
    metadataMap['source'] = item.source.toMap();
    final metadataJson = jsonEncode(metadataMap);
    final now = DateTime.now().toIso8601String();

    _db.execute(
      '''
      INSERT INTO media_items (
        id, title, type, sourceType, sourceUri, author, album, durationMs,
        coverArtUri, chaptersJson, lastPositionMs, isCompleted, lastPlayedAt,
        metadataJson, createdAt, updatedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        type = excluded.type,
        sourceType = excluded.sourceType,
        sourceUri = excluded.sourceUri,
        author = excluded.author,
        album = excluded.album,
        durationMs = excluded.durationMs,
        coverArtUri = excluded.coverArtUri,
        chaptersJson = excluded.chaptersJson,
        lastPositionMs = excluded.lastPositionMs,
        isCompleted = excluded.isCompleted,
        lastPlayedAt = excluded.lastPlayedAt,
        metadataJson = excluded.metadataJson,
        updatedAt = excluded.updatedAt;
      ''',
      [
        item.id,
        item.title,
        item.type.name,
        item.source.type.name,
        item.source.uri,
        item.author,
        item.album,
        item.durationMs,
        item.coverArtUri,
        chaptersJson,
        item.lastPosition.milliseconds,
        item.isCompleted ? 1 : 0,
        item.lastPlayedAt?.toIso8601String(),
        metadataJson,
        now,
        now,
      ],
    );
    _notifyMediaChanged(item.id);
  }

  /// Deletes a media item from the database.
  Future<void> deleteMediaItem(String id) async {
    _db.execute('DELETE FROM media_items WHERE id = ?;', [id]);
    _notifyMediaChanged(id);
  }

  /// Updates exact millisecond playback position and completion status.
  Future<void> updatePlaybackPosition(
    String id,
    PlaybackPosition position, {
    bool? isCompleted,
    DateTime? lastPlayedAt,
  }) async {
    final existing = await getMediaItemById(id);
    if (existing == null) {
      throw StateError('MediaItem mit ID $id nicht gefunden.');
    }

    final compVal = isCompleted ?? existing.isCompleted;
    final playedAtVal = lastPlayedAt ?? DateTime.now();
    final now = DateTime.now().toIso8601String();

    _db.execute(
      '''
      UPDATE media_items SET
        lastPositionMs = ?,
        isCompleted = ?,
        lastPlayedAt = ?,
        updatedAt = ?
      WHERE id = ?;
      ''',
      [
        position.milliseconds,
        compVal ? 1 : 0,
        playedAtVal.toIso8601String(),
        now,
        id,
      ],
    );
    _notifyMediaChanged(id);
  }

  /// Batch upsert for media items inside an atomic transaction.
  Future<void> batchUpsertMediaItems(List<MediaItem> items) async {
    await transaction(() async {
      for (final item in items) {
        await upsertMediaItem(item);
      }
    });
    _notifyMediaChanged();
  }

  // ==================== BOOKMARKS ====================

  /// Watches all bookmarks for a specific media item.
  Stream<List<Bookmark>> watchBookmarksForMedia(String mediaItemId) async* {
    yield await getBookmarksForMedia(mediaItemId);
    final ctrl = _mediaBookmarkControllers.putIfAbsent(
      mediaItemId,
      () => StreamController<List<Bookmark>>.broadcast(),
    );
    yield* ctrl.stream;
  }

  /// Retrieves bookmarks for a media item sorted ascending by position.
  Future<List<Bookmark>> getBookmarksForMedia(String mediaItemId) async {
    final rows = _db.select(
      'SELECT * FROM bookmarks WHERE mediaItemId = ? ORDER BY positionMs ASC;',
      [mediaItemId],
    );
    return rows.map(_rowToBookmark).toList();
  }

  /// Inserts a bookmark.
  Future<void> insertBookmark(Bookmark bookmark) async {
    try {
      _db.execute(
        '''
        INSERT INTO bookmarks (id, mediaItemId, positionMs, createdAt, label, note)
        VALUES (?, ?, ?, ?, ?, ?);
        ''',
        [
          bookmark.id,
          bookmark.mediaItemId,
          bookmark.positionMs,
          bookmark.createdAt.toIso8601String(),
          bookmark.label,
          bookmark.note,
        ],
      );
    } on SqliteException catch (e) {
      if (e.resultCode == 787 || e.message.contains('FOREIGN KEY')) {
        throw StateError(
          'Fremdschluessel-Verletzung: MediaItem ${bookmark.mediaItemId} existiert nicht.',
        );
      }
      rethrow;
    }
    _notifyBookmarksChanged(bookmark.mediaItemId);
  }

  /// Deletes a bookmark by its ID.
  Future<void> deleteBookmark(String id) async {
    final rows =
        _db.select('SELECT mediaItemId FROM bookmarks WHERE id = ?;', [id]);
    _db.execute('DELETE FROM bookmarks WHERE id = ?;', [id]);
    if (rows.isNotEmpty) {
      _notifyBookmarksChanged(rows.first['mediaItemId'] as String);
    }
  }

  /// Deletes all bookmarks for a media item.
  Future<void> deleteBookmarksForMedia(String mediaItemId) async {
    _db.execute(
        'DELETE FROM bookmarks WHERE mediaItemId = ?;', [mediaItemId]);
    _notifyBookmarksChanged(mediaItemId);
  }

  // ==================== PLAYBACK HISTORY ====================

  /// Records a playback session in history.
  Future<void> recordPlaybackHistory(PlaybackHistoryEntry entry) async {
    try {
      _db.execute(
        '''
        INSERT INTO playback_history (
          id, mediaItemId, playedAt, playbackDurationMs, startPositionMs, endPositionMs, wasCompleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          entry.id,
          entry.mediaItemId,
          entry.playedAt.toIso8601String(),
          entry.playbackDurationMs,
          entry.startPositionMs,
          entry.endPositionMs,
          entry.wasCompleted ? 1 : 0,
        ],
      );
    } on SqliteException catch (e) {
      if (e.resultCode == 787 || e.message.contains('FOREIGN KEY')) {
        throw StateError(
          'Fremdschluessel-Verletzung: MediaItem ${entry.mediaItemId} existiert nicht.',
        );
      }
      rethrow;
    }
  }

  /// Retrieves playback history for a media item sorted descending by played date.
  Future<List<PlaybackHistoryEntry>> getPlaybackHistory(
    String mediaItemId, {
    int limit = 50,
  }) async {
    final rows = _db.select(
      'SELECT * FROM playback_history WHERE mediaItemId = ? ORDER BY playedAt DESC LIMIT ?;',
      [mediaItemId, limit],
    );
    return rows.map(_rowToHistory).toList();
  }

  /// Retrieves all playback history records.
  Future<List<PlaybackHistoryEntry>> getAllHistory() async {
    final rows = _db.select(
        'SELECT * FROM playback_history ORDER BY playedAt DESC;');
    return rows.map(_rowToHistory).toList();
  }

  /// Deletes a history entry by ID.
  Future<void> deleteHistoryEntry(String id) async {
    _db.execute('DELETE FROM playback_history WHERE id = ?;', [id]);
  }

  /// Clears playback history, optionally filtered by mediaItemId.
  Future<void> clearPlaybackHistory({String? mediaItemId}) async {
    if (mediaItemId != null) {
      _db.execute(
          'DELETE FROM playback_history WHERE mediaItemId = ?;', [mediaItemId]);
    } else {
      _db.execute('DELETE FROM playback_history;');
    }
  }

  // ==================== SLEEP PRESETS ====================

  /// Retrieves all sleep presets sorted ascending by duration in minutes.
  Future<List<SleepPresetEntry>> getSleepPresets() async {
    final rows =
        _db.select('SELECT * FROM sleep_presets ORDER BY durationMinutes ASC;');
    return rows.map(_rowToPreset).toList();
  }

  /// Retrieves a sleep preset by ID.
  Future<SleepPresetEntry?> getSleepPresetById(String id) async {
    final rows =
        _db.select('SELECT * FROM sleep_presets WHERE id = ?;', [id]);
    if (rows.isEmpty) return null;
    return _rowToPreset(rows.first);
  }

  /// Inserts or replaces a sleep preset.
  Future<void> insertSleepPreset(SleepPresetEntry preset) async {
    _db.execute(
      '''
      INSERT OR REPLACE INTO sleep_presets (
        id, name, durationMinutes, autoFadeOutSeconds, shakeGracePeriodSeconds, autoRewindSeconds, isDefault
      ) VALUES (?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        preset.id,
        preset.name,
        preset.durationMinutes,
        preset.autoFadeOutSeconds,
        preset.shakeGracePeriodSeconds,
        preset.autoRewindSeconds,
        preset.isDefault ? 1 : 0,
      ],
    );
  }

  /// Deletes a sleep preset by ID.
  Future<void> deleteSleepPreset(String id) async {
    _db.execute('DELETE FROM sleep_presets WHERE id = ?;', [id]);
  }

  /// Sets a preset as default and unsets all others.
  Future<void> setDefaultSleepPreset(String id) async {
    await transaction(() async {
      _db.execute('UPDATE sleep_presets SET isDefault = 0;');
      _db.execute('UPDATE sleep_presets SET isDefault = 1 WHERE id = ?;', [id]);
    });
  }

  // ==================== PLAYBACK QUEUE ====================

  /// Saves the entire playback queue atomically.
  Future<void> savePlaybackQueue(
    List<String> mediaItemIds, {
    int currentIndex = 0,
  }) async {
    await transaction(() async {
      _db.execute('DELETE FROM playback_queue;');
      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < mediaItemIds.length; i++) {
        final id = 'queue_$i';
        _db.execute(
          '''
          INSERT INTO playback_queue (id, mediaItemId, sortOrder, addedAt, isCurrent)
          VALUES (?, ?, ?, ?, ?);
          ''',
          [id, mediaItemIds[i], i, now, i == currentIndex ? 1 : 0],
        );
      }
    });
    _notifyQueueChanged();
  }

  /// Loads media item IDs in queue sorted by sortOrder.
  Future<List<String>> getPlaybackQueue() async {
    final rows = _db
        .select('SELECT mediaItemId FROM playback_queue ORDER BY sortOrder ASC;');
    return rows.map((r) => r['mediaItemId'] as String).toList();
  }

  /// Loads current index of the active playback queue item.
  Future<int> getPlaybackQueueCurrentIndex() async {
    final rows = _db.select(
        'SELECT sortOrder FROM playback_queue WHERE isCurrent = 1 LIMIT 1;');
    if (rows.isNotEmpty) {
      return (rows.first['sortOrder'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Watches queue reactively as stream of media item IDs.
  Stream<List<String>> watchPlaybackQueue() async* {
    yield await getPlaybackQueue();
    yield* _queueController.stream;
  }

  /// Clears the playback queue.
  Future<void> clearPlaybackQueue() async {
    _db.execute('DELETE FROM playback_queue;');
    _notifyQueueChanged();
  }

  // ==================== PLAYLISTS & FAVORITES (TICK-V2-09) ====================

  /// Creates a new playlist.
  Future<PlaylistEntry> createPlaylist(
    String name, {
    String? id,
    String kind = 'custom',
    String? sourcePath,
    int sortOrder = 0,
  }) async {
    final playlistId =
        id ?? 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    final createdAt = DateTime.now();

    final entry = PlaylistEntry(
      id: playlistId,
      name: name,
      kind: kind,
      sourcePath: sourcePath,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );

    _db.execute(
      '''
      INSERT INTO playlists (id, name, kind, sourcePath, sortOrder, createdAt)
      VALUES (?, ?, ?, ?, ?, ?);
      ''',
      [
        entry.id,
        entry.name,
        entry.kind,
        entry.sourcePath,
        entry.sortOrder,
        entry.createdAt.toIso8601String(),
      ],
    );
    _notifyPlaylistsChanged();
    return entry;
  }

  /// Returns all playlists.
  Future<List<PlaylistEntry>> getPlaylists() async {
    final rows = _db.select(
        'SELECT * FROM playlists ORDER BY sortOrder ASC, createdAt ASC;');
    return rows.map(_rowToPlaylist).toList();
  }

  /// Returns all playlists sorted by creation time descending (most recent first).
  Future<List<PlaylistEntry>> getPlaylistsSortedByRecent() async {
    final rows =
        _db.select('SELECT * FROM playlists ORDER BY createdAt DESC;');
    return rows.map(_rowToPlaylist).toList();
  }

  /// Deletes a playlist and its associated items.
  Future<void> deletePlaylist(String playlistId) async {
    await transaction(() async {
      _db.execute(
          'DELETE FROM playlist_items WHERE playlistId = ?;', [playlistId]);
      _db.execute('DELETE FROM playlists WHERE id = ?;', [playlistId]);
    });
    _notifyPlaylistsChanged();
  }

  /// Adds items to a playlist.
  Future<void> addItemsToPlaylist(
      String playlistId, List<String> mediaItemIds) async {
    await transaction(() async {
      final now = DateTime.now().toIso8601String();
      final maxOrderRows = _db.select(
        'SELECT MAX(sortOrder) as maxOrder FROM playlist_items WHERE playlistId = ?;',
        [playlistId],
      );
      int currentOrder = 0;
      if (maxOrderRows.isNotEmpty && maxOrderRows.first['maxOrder'] != null) {
        currentOrder = (maxOrderRows.first['maxOrder'] as num).toInt() + 1;
      }

      for (final mediaId in mediaItemIds) {
        _db.execute(
          '''
          INSERT OR REPLACE INTO playlist_items (playlistId, mediaItemId, addedAt, sortOrder)
          VALUES (?, ?, ?, ?);
          ''',
          [playlistId, mediaId, now, currentOrder++],
        );
      }
    });
    _notifyPlaylistsChanged();
  }

  /// Removes items from a playlist.
  Future<void> removeItemsFromPlaylist(
      String playlistId, List<String> mediaItemIds) async {
    await transaction(() async {
      for (final mediaId in mediaItemIds) {
        _db.execute(
          'DELETE FROM playlist_items WHERE playlistId = ? AND mediaItemId = ?;',
          [playlistId, mediaId],
        );
      }
    });
    _notifyPlaylistsChanged();
  }

  /// Retrieves media item IDs for a given playlist in sort order.
  Future<List<String>> getPlaylistItems(String playlistId) async {
    final rows = _db.select(
      'SELECT mediaItemId FROM playlist_items WHERE playlistId = ? ORDER BY sortOrder ASC, addedAt ASC;',
      [playlistId],
    );
    return rows.map((r) => r['mediaItemId'] as String).toList();
  }

  /// Watches all playlists reactively.
  Stream<List<PlaylistEntry>> watchPlaylists() async* {
    yield await getPlaylistsSortedByRecent();
    yield* _playlistsController.stream;
  }

  /// Toggles favorite status of a media item.
  Future<bool> toggleFavorite(String mediaItemId) async {
    bool isNowFav = false;
    await transaction(() async {
      final check = _db.select(
          'SELECT 1 FROM favorites WHERE mediaItemId = ?;', [mediaItemId]);
      if (check.isNotEmpty) {
        _db.execute(
            'DELETE FROM favorites WHERE mediaItemId = ?;', [mediaItemId]);
        isNowFav = false;
      } else {
        _db.execute(
          'INSERT INTO favorites (mediaItemId, addedAt) VALUES (?, ?);',
          [mediaItemId, DateTime.now().toIso8601String()],
        );
        isNowFav = true;
      }
    });
    _notifyFavoritesChanged();
    return isNowFav;
  }

  /// Checks if a media item is marked as favorite.
  Future<bool> isFavorite(String mediaItemId) async {
    final rows = _db.select(
        'SELECT 1 FROM favorites WHERE mediaItemId = ?;', [mediaItemId]);
    return rows.isNotEmpty;
  }

  /// Returns all favorite media item IDs sorted by addedAt descending.
  Future<List<String>> getFavorites() async {
    final rows =
        _db.select('SELECT mediaItemId FROM favorites ORDER BY addedAt DESC;');
    return rows.map((r) => r['mediaItemId'] as String).toList();
  }

  /// Watches favorites reactively as a set of mediaItemIds.
  Stream<Set<String>> watchFavorites() async* {
    final favList = await getFavorites();
    yield favList.toSet();
    yield* _favoritesController.stream;
  }

  /// Closes all active stream controllers and clears cached controllers.
  Future<void> close() async {
    await _mediaListController.close();
    await _queueController.close();
    await _playlistsController.close();
    await _favoritesController.close();
    for (final ctrl in _singleMediaControllers.values) {
      await ctrl.close();
    }
    for (final ctrl in _mediaBookmarkControllers.values) {
      await ctrl.close();
    }
    _singleMediaControllers.clear();
    _mediaBookmarkControllers.clear();
  }
}
