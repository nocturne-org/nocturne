import '../../domain/models/bookmark.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';

/// Repository-Schnittstelle fuer den Zugriff auf Medien, Lesezeichen und Wiedergabedaten.
abstract class MediaRepository {
  /// Beobachtet alle verfuegbaren Medien reaktiv als Stream.
  Stream<List<MediaItem>> watchAllMedia();

  /// Beobachtet ein einzelnes Medium anhand seiner ID reaktiv.
  Stream<MediaItem?> watchMediaById(String id);

  /// Laedt alle Medien asynchron.
  Future<List<MediaItem>> getAllMedia();

  /// Laedt ein einzelnes Medium asynchron anhand seiner ID.
  Future<MediaItem?> getMediaById(String id);

  /// Speichert ein neues oder modifiziertes Medium.
  Future<void> saveMedia(MediaItem item);

  /// Loescht ein Medium und kaskadierend alle Lesezeichen und Historieeintraege.
  Future<void> deleteMedia(String id);

  /// Aktualisiert die Abspielposition millisekunden-genau.
  Future<void> updatePosition(
    String id,
    PlaybackPosition position, {
    bool? isCompleted,
    DateTime? lastPlayedAt,
  });

  /// Fuehrt einen transaktionalen Batch-Import mehrerer Medien durch.
  Future<void> batchImportMedia(List<MediaItem> items);

  /// Beobachtet alle Lesezeichen fuer ein bestimmtes Medium.
  Stream<List<Bookmark>> watchBookmarks(String mediaItemId);

  /// Speichert ein Lesezeichen.
  Future<void> addBookmark(Bookmark bookmark);

  /// Loescht ein Lesezeichen anhand seiner ID.
  Future<void> deleteBookmark(String id);

  /// Speichert die IDs der Wiedergabe-Warteschlange persistent ab.
  Future<void> savePlaybackQueue(List<String> mediaItemIds,
      {int currentIndex = 0});

  /// Laedt die persistent gespeicherte Warteschlange.
  Future<List<String>> loadPlaybackQueue();

  /// Laedt den aktuellen Index der gespeicherten Warteschlange.
  Future<int> loadPlaybackQueueCurrentIndex();

  /// Beobachtet die persistent gespeicherte Warteschlange reaktiv als Stream.
  Stream<List<String>> watchPlaybackQueue();

  /// Leert die gespeicherte Warteschlange.
  Future<void> clearPlaybackQueue();
}
