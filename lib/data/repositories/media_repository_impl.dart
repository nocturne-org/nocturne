import '../../domain/models/bookmark.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';
import '../datasources/database/app_database.dart';
import 'media_repository.dart';

/// Clean-Architecture-Implementierung von [MediaRepository] basierend auf [AppDatabase].
class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  @override
  Stream<List<MediaItem>> watchAllMedia() => _db.mediaDao.watchAllMediaItems();

  @override
  Stream<MediaItem?> watchMediaById(String id) =>
      _db.mediaDao.watchMediaItemById(id);

  @override
  Future<List<MediaItem>> getAllMedia() => _db.mediaDao.getAllMediaItems();

  @override
  Future<MediaItem?> getMediaById(String id) =>
      _db.mediaDao.getMediaItemById(id);

  @override
  Future<void> saveMedia(MediaItem item) => _db.mediaDao.upsertMediaItem(item);

  @override
  Future<void> deleteMedia(String id) => _db.mediaDao.deleteMediaItem(id);

  @override
  Future<void> updatePosition(
    String id,
    PlaybackPosition position, {
    bool? isCompleted,
    DateTime? lastPlayedAt,
  }) {
    return _db.mediaDao.updatePlaybackPosition(
      id,
      position,
      isCompleted: isCompleted,
      lastPlayedAt: lastPlayedAt,
    );
  }

  @override
  Future<void> batchImportMedia(List<MediaItem> items) =>
      _db.mediaDao.batchUpsertMediaItems(items);

  @override
  Stream<List<Bookmark>> watchBookmarks(String mediaItemId) =>
      _db.mediaDao.watchBookmarksForMedia(mediaItemId);

  @override
  Future<void> addBookmark(Bookmark bookmark) =>
      _db.mediaDao.insertBookmark(bookmark);

  @override
  Future<void> deleteBookmark(String id) => _db.mediaDao.deleteBookmark(id);

  @override
  Future<void> savePlaybackQueue(List<String> mediaItemIds,
          {int currentIndex = 0}) =>
      _db.mediaDao.savePlaybackQueue(mediaItemIds, currentIndex: currentIndex);

  @override
  Future<List<String>> loadPlaybackQueue() => _db.mediaDao.getPlaybackQueue();

  @override
  Future<int> loadPlaybackQueueCurrentIndex() =>
      _db.mediaDao.getPlaybackQueueCurrentIndex();

  @override
  Stream<List<String>> watchPlaybackQueue() =>
      _db.mediaDao.watchPlaybackQueue();

  @override
  Future<void> clearPlaybackQueue() => _db.mediaDao.clearPlaybackQueue();
}
