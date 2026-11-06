import 'dart:async';
import '../../../../domain/models/bookmark.dart';
import '../../../../domain/models/media_item.dart';
import '../../../../domain/models/playback_position.dart';

/// Daten-Entitaet fuer einen Eintrag in der Abspiel-Historie.
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

/// Daten-Entitaet fuer ein konfigurierbares Sleep-Timer Profil.
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

/// Daten-Entitaet fuer einen persistenten Eintrag der Abspiel-Warteschlange.
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
    required this.createdAt,
  });

  final String id;
  final String name;
  final String kind;
  final String? sourcePath;
  final DateTime createdAt;

  PlaylistEntry copyWith({
    String? id,
    String? name,
    String? kind,
    String? sourcePath,
    DateTime? createdAt,
  }) {
    return PlaylistEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sourcePath: sourcePath ?? this.sourcePath,
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

/// Typensicheres Data Access Object (DAO) fuer Medien, Lesezeichen,
/// Historie und Sleep-Presets mit reaktiven Streams (watch).
class MediaDao {
  MediaDao({
    Future<T> Function<T>(Future<T> Function() action)? transactionRunner,
  }) : _transactionRunner = transactionRunner;

  final Future<T> Function<T>(Future<T> Function() action)? _transactionRunner;

  /// Fuehrt eine Aktion innerhalb einer Transaktion aus.
  Future<T> transaction<T>(Future<T> Function() action) async {
    final runner = _transactionRunner;
    if (runner != null) {
      return await runner(action);
    }
    return await action();
  }

  final Map<String, MediaItem> _mediaStore = {};
  final Map<String, Bookmark> _bookmarkStore = {};
  final Map<String, PlaybackHistoryEntry> _historyStore = {};
  final Map<String, SleepPresetEntry> _presetStore = {};
  final Map<String, PlaybackQueueEntry> _queueStore = {};
  final Map<String, PlaylistEntry> _playlistStore = {};
  final List<PlaylistItemEntry> _playlistItemStore = [];
  final Map<String, FavoriteEntry> _favoriteStore = {};

  final StreamController<List<PlaylistEntry>> _playlistsController =
      StreamController<List<PlaylistEntry>>.broadcast();
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  final StreamController<List<MediaItem>> _mediaListController =
      StreamController<List<MediaItem>>.broadcast();

  final Map<String, StreamController<MediaItem?>> _singleMediaControllers = {};
  final Map<String, StreamController<List<Bookmark>>>
      _mediaBookmarkControllers = {};
  final StreamController<List<String>> _queueController =
      StreamController<List<String>>.broadcast();

  void _notifyMediaChanged([String? specificId]) {
    final list = _mediaStore.values.toList();
    if (!_mediaListController.isClosed) {
      _mediaListController.add(list);
    }

    if (specificId != null) {
      final ctrl = _singleMediaControllers[specificId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(_mediaStore[specificId]);
      }
    } else {
      for (final entry in _singleMediaControllers.entries) {
        if (!entry.value.isClosed) {
          entry.value.add(_mediaStore[entry.key]);
        }
      }
    }
  }

  void _notifyBookmarksChanged(String mediaItemId) {
    final ctrl = _mediaBookmarkControllers[mediaItemId];
    if (ctrl != null && !ctrl.isClosed) {
      final list = _bookmarkStore.values
          .where((b) => b.mediaItemId == mediaItemId)
          .toList()
        ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
      ctrl.add(list);
    }
  }

  // ==================== MEDIA ITEMS ====================

  /// Reaktiv alle Medien beobachten.
  Stream<List<MediaItem>> watchAllMediaItems() async* {
    yield _mediaStore.values.toList();
    yield* _mediaListController.stream;
  }

  /// Reaktiv ein einzelnes Medium anhand seiner ID beobachten.
  Stream<MediaItem?> watchMediaItemById(String id) async* {
    yield _mediaStore[id];
    final ctrl = _singleMediaControllers.putIfAbsent(
      id,
      () => StreamController<MediaItem?>.broadcast(),
    );
    yield* ctrl.stream;
  }

  /// Liefert alle gespeicherten Medien.
  Future<List<MediaItem>> getAllMediaItems() async {
    return _mediaStore.values.toList();
  }

  /// Liefert ein einzelnes Medium anhand der ID.
  Future<MediaItem?> getMediaItemById(String id) async {
    return _mediaStore[id];
  }

  /// Fuegt ein neues Medium ein. Wirft Fehler, falls ID bereits existiert.
  Future<void> insertMediaItem(MediaItem item) async {
    if (_mediaStore.containsKey(item.id)) {
      throw StateError('MediaItem mit ID ${item.id} existiert bereits.');
    }
    _mediaStore[item.id] = item;
    _notifyMediaChanged(item.id);
  }

  /// Aktualisiert ein existierendes Medium.
  Future<void> updateMediaItem(MediaItem item) async {
    if (!_mediaStore.containsKey(item.id)) {
      throw StateError('MediaItem mit ID ${item.id} existiert nicht.');
    }
    _mediaStore[item.id] = item;
    _notifyMediaChanged(item.id);
  }

  /// Fuegt ein Medium ein oder aktualisiert es, falls bereits vorhanden.
  Future<void> upsertMediaItem(MediaItem item) async {
    _mediaStore[item.id] = item;
    _notifyMediaChanged(item.id);
  }

  /// Loescht ein Medium und entfernt kaskadierend alle zugeordneten
  /// Lesezeichen und Historien-Eintraege.
  Future<void> deleteMediaItem(String id) async {
    _mediaStore.remove(id);

    // Kaskadierendes Loeschen der Lesezeichen
    final bookmarksToDelete = _bookmarkStore.values
        .where((b) => b.mediaItemId == id)
        .map((b) => b.id)
        .toList();
    for (final bId in bookmarksToDelete) {
      _bookmarkStore.remove(bId);
    }

    // Kaskadierendes Loeschen der Historie
    final historyToDelete = _historyStore.values
        .where((h) => h.mediaItemId == id)
        .map((h) => h.id)
        .toList();
    for (final hId in historyToDelete) {
      _historyStore.remove(hId);
    }

    // Kaskadierendes Entfernen aus der Warteschlange
    final hadQueueItem = _queueStore.values.any((q) => q.mediaItemId == id);
    _queueStore.removeWhere((_, q) => q.mediaItemId == id);
    if (hadQueueItem) {
      _notifyQueueChanged();
    }

    _notifyMediaChanged(id);
    _notifyBookmarksChanged(id);
  }

  /// Millisekunden-genaue Speicherung und Abruf der letzten Abspielposition.
  Future<void> updatePlaybackPosition(
    String id,
    PlaybackPosition position, {
    bool? isCompleted,
    DateTime? lastPlayedAt,
  }) async {
    final existing = _mediaStore[id];
    if (existing == null) {
      throw StateError('MediaItem mit ID $id nicht gefunden.');
    }

    final updated = existing.copyWith(
      lastPosition: position,
      isCompleted: isCompleted ?? existing.isCompleted,
      lastPlayedAt: lastPlayedAt ?? DateTime.now(),
    );

    _mediaStore[id] = updated;
    _notifyMediaChanged(id);
  }

  /// Fuehrt Batch-Updates atomar mit transaktionaler Integritaet aus.
  Future<void> batchUpsertMediaItems(List<MediaItem> items) async {
    final runner = _transactionRunner;
    if (runner != null) {
      await runner(() async {
        for (final item in items) {
          _mediaStore[item.id] = item;
        }
      });
    } else {
      // Fallback: Direkte atomare In-Memory Zuweisung
      final backup = Map<String, MediaItem>.from(_mediaStore);
      try {
        for (final item in items) {
          _mediaStore[item.id] = item;
        }
      } catch (_) {
        _mediaStore
          ..clear()
          ..addAll(backup);
        rethrow;
      }
    }
    _notifyMediaChanged();
  }

  // ==================== BOOKMARKS ====================

  /// Reaktiv alle Lesezeichen fuer ein Medium beobachten.
  Stream<List<Bookmark>> watchBookmarksForMedia(String mediaItemId) async* {
    yield await getBookmarksForMedia(mediaItemId);
    final ctrl = _mediaBookmarkControllers.putIfAbsent(
      mediaItemId,
      () => StreamController<List<Bookmark>>.broadcast(),
    );
    yield* ctrl.stream;
  }

  /// Liefert alle Lesezeichen fuer ein Medium, sortiert nach Position (aufsteigend).
  Future<List<Bookmark>> getBookmarksForMedia(String mediaItemId) async {
    final list = _bookmarkStore.values
        .where((b) => b.mediaItemId == mediaItemId)
        .toList()
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return list;
  }

  /// Speichert ein Lesezeichen millisekunden-genau ab.
  Future<void> insertBookmark(Bookmark bookmark) async {
    if (!_mediaStore.containsKey(bookmark.mediaItemId)) {
      throw StateError(
        'Fremdschluessel-Verletzung: MediaItem ${bookmark.mediaItemId} existiert nicht.',
      );
    }
    _bookmarkStore[bookmark.id] = bookmark;
    _notifyBookmarksChanged(bookmark.mediaItemId);
  }

  /// Loescht ein Lesezeichen anhand seiner ID.
  Future<void> deleteBookmark(String id) async {
    final removed = _bookmarkStore.remove(id);
    if (removed != null) {
      _notifyBookmarksChanged(removed.mediaItemId);
    }
  }

  // ==================== PLAYBACK HISTORY ====================

  /// Zeichnet eine Wiedergabesitzung in der Historie auf.
  Future<void> recordPlaybackHistory(PlaybackHistoryEntry entry) async {
    if (!_mediaStore.containsKey(entry.mediaItemId)) {
      throw StateError(
        'Fremdschluessel-Verletzung: MediaItem ${entry.mediaItemId} existiert nicht.',
      );
    }
    _historyStore[entry.id] = entry;
  }

  /// Liefert die Abspiel-Historie fuer ein Medium, sortiert nach Datum (neueste zuerst).
  Future<List<PlaybackHistoryEntry>> getPlaybackHistory(
    String mediaItemId, {
    int limit = 50,
  }) async {
    final list = _historyStore.values
        .where((h) => h.mediaItemId == mediaItemId)
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    if (list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  /// Bereinigt die Abspiel-Historie (optional gefiltert nach MediaItem).
  Future<void> clearPlaybackHistory({String? mediaItemId}) async {
    if (mediaItemId != null) {
      _historyStore.removeWhere((_, h) => h.mediaItemId == mediaItemId);
    } else {
      _historyStore.clear();
    }
  }

  // ==================== SLEEP PRESETS ====================

  /// Liefert alle gespeicherten Sleep-Timer Profile.
  Future<List<SleepPresetEntry>> getSleepPresets() async {
    final list = _presetStore.values.toList()
      ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return list;
  }

  /// Liefert ein einzelnes Sleep-Timer Profil.
  Future<SleepPresetEntry?> getSleepPresetById(String id) async {
    return _presetStore[id];
  }

  /// Speichert ein Sleep-Timer Profil ab.
  Future<void> insertSleepPreset(SleepPresetEntry preset) async {
    _presetStore[preset.id] = preset;
  }

  /// Loescht ein Sleep-Timer Profil.
  Future<void> deleteSleepPreset(String id) async {
    _presetStore.remove(id);
  }

  // ==================== PLAYBACK QUEUE ====================

  /// Speichert die gesamte Warteschlange atomar persistent ab.
  Future<void> savePlaybackQueue(
    List<String> mediaItemIds, {
    int currentIndex = 0,
  }) async {
    await transaction(() async {
      _queueStore.clear();
      for (var i = 0; i < mediaItemIds.length; i++) {
        final id = 'queue_$i';
        _queueStore[id] = PlaybackQueueEntry(
          id: id,
          mediaItemId: mediaItemIds[i],
          sortOrder: i,
          addedAt: DateTime.now(),
          isCurrent: i == currentIndex,
        );
      }
      _notifyQueueChanged();
    });
  }

  /// Laedt alle MediaItem-IDs der Warteschlange sortiert nach SortOrder.
  Future<List<String>> getPlaybackQueue() async {
    final entries = _queueStore.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return entries.map((e) => e.mediaItemId).toList();
  }

  /// Laedt den Index des aktuell aktiven Eintrags.
  Future<int> getPlaybackQueueCurrentIndex() async {
    final entries = _queueStore.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isCurrent) return i;
    }
    return 0;
  }

  /// Beobachtet die Warteschlange reaktiv als Stream von MediaItem-IDs.
  Stream<List<String>> watchPlaybackQueue() async* {
    yield await getPlaybackQueue();
    yield* _queueController.stream;
  }

  /// Leert die gespeicherte Warteschlange.
  Future<void> clearPlaybackQueue() async {
    _queueStore.clear();
    _notifyQueueChanged();
  }

  void _notifyQueueChanged() {
    if (!_queueController.isClosed) {
      final entries = _queueStore.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _queueController.add(entries.map((e) => e.mediaItemId).toList());
    }
  }

  // ==================== PLAYLISTS & FAVORITES (TICK-V2-09) ====================

  /// Creates a new playlist.
  Future<PlaylistEntry> createPlaylist(
    String name, {
    String kind = 'custom',
    String? sourcePath,
    String? id,
  }) async {
    final playlistId = id ?? 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    final entry = PlaylistEntry(
      id: playlistId,
      name: name,
      kind: kind,
      sourcePath: sourcePath,
      createdAt: DateTime.now(),
    );
    _playlistStore[playlistId] = entry;
    _notifyPlaylistsChanged();
    return entry;
  }

  /// Returns all playlists.
  Future<List<PlaylistEntry>> getPlaylists() async {
    return _playlistStore.values.toList();
  }

  /// Returns all playlists sorted by creation time descending (most recent first).
  Future<List<PlaylistEntry>> getPlaylistsSortedByRecent() async {
    final list = _playlistStore.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Deletes a playlist and its associated items.
  Future<void> deletePlaylist(String playlistId) async {
    _playlistStore.remove(playlistId);
    _playlistItemStore.removeWhere((item) => item.playlistId == playlistId);
    _notifyPlaylistsChanged();
  }

  /// Adds items to a playlist.
  Future<void> addItemsToPlaylist(String playlistId, List<String> mediaItemIds) async {
    for (var i = 0; i < mediaItemIds.length; i++) {
      _playlistItemStore.add(PlaylistItemEntry(
        playlistId: playlistId,
        mediaItemId: mediaItemIds[i],
        addedAt: DateTime.now(),
        sortOrder: i,
      ));
    }
    _notifyPlaylistsChanged();
  }

  /// Removes items from a playlist.
  Future<void> removeItemsFromPlaylist(String playlistId, List<String> mediaItemIds) async {
    final idSet = mediaItemIds.toSet();
    _playlistItemStore.removeWhere((item) =>
        item.playlistId == playlistId && idSet.contains(item.mediaItemId));
    _notifyPlaylistsChanged();
  }

  /// Retrieves media item IDs for a given playlist in sort order.
  Future<List<String>> getPlaylistItems(String playlistId) async {
    final items = _playlistItemStore
        .where((item) => item.playlistId == playlistId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items.map((i) => i.mediaItemId).toList();
  }

  /// Watches all playlists reactively.
  Stream<List<PlaylistEntry>> watchPlaylists() async* {
    yield await getPlaylistsSortedByRecent();
    yield* _playlistsController.stream;
  }

  void _notifyPlaylistsChanged() {
    if (!_playlistsController.isClosed) {
      final list = _playlistStore.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _playlistsController.add(list);
    }
  }

  /// Toggles favorite status of a media item.
  Future<bool> toggleFavorite(String mediaItemId) async {
    final isFav = _favoriteStore.containsKey(mediaItemId);
    if (isFav) {
      _favoriteStore.remove(mediaItemId);
    } else {
      _favoriteStore[mediaItemId] = FavoriteEntry(
        mediaItemId: mediaItemId,
        addedAt: DateTime.now(),
      );
    }
    _notifyFavoritesChanged();
    return !isFav;
  }

  /// Checks if a media item is marked as favorite.
  Future<bool> isFavorite(String mediaItemId) async {
    return _favoriteStore.containsKey(mediaItemId);
  }

  /// Returns all favorite media item IDs sorted by addedAt descending.
  Future<List<String>> getFavorites() async {
    final list = _favoriteStore.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list.map((f) => f.mediaItemId).toList();
  }

  /// Watches favorites reactively as a set of mediaItemIds.
  Stream<Set<String>> watchFavorites() async* {
    yield _favoriteStore.keys.toSet();
    yield* _favoritesController.stream;
  }

  void _notifyFavoritesChanged() {
    if (!_favoritesController.isClosed) {
      _favoritesController.add(_favoriteStore.keys.toSet());
    }
  }

  /// Schliesst alle offenen Stream-Controller.
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
