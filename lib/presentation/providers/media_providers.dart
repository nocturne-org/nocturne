import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';
import 'repository_providers.dart';

/// AsyncNotifier fuer die Liste aller Medien.
/// Behandelt Lade-, Fehler- und Erfolgszustaende vollautomatisch als [AsyncValue].
class MediaListNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    final repo = ref.watch(mediaRepositoryProvider);
    return repo.getAllMedia();
  }

  /// Aktualisiert die Liste aus der Datenbank.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(mediaRepositoryProvider);
      return repo.getAllMedia();
    });
  }

  /// Loescht ein Medium und aktualisiert den asynchronen Zustand.
  Future<void> deleteMedia(String id) async {
    final repo = ref.read(mediaRepositoryProvider);
    await repo.deleteMedia(id);
    await refresh();
  }

  /// Fuehrt einen Batch-Import durch und laedt die Liste neu.
  Future<void> batchImportMedia(List<MediaItem> items) async {
    final repo = ref.read(mediaRepositoryProvider);
    await repo.batchImportMedia(items);
    await refresh();
  }
}

/// Provider fuer [MediaListNotifier].
final mediaListNotifierProvider =
    AsyncNotifierProvider<MediaListNotifier, List<MediaItem>>(
  MediaListNotifier.new,
);

/// AsyncNotifier fuer das aktuell ausgewaehlte bzw. wiedergegebene Medium.
class ActiveMediaNotifier extends AsyncNotifier<MediaItem?> {
  @override
  Future<MediaItem?> build() async {
    return null;
  }

  /// Waehlt ein Medium anhand der ID als aktiv aus.
  Future<void> selectMedia(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(mediaRepositoryProvider);
      return repo.getMediaById(id);
    });
  }

  /// Aktualisiert die Abspielposition des aktiven Mediums millisekunden-genau.
  Future<void> updatePosition(PlaybackPosition position) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final repo = ref.read(mediaRepositoryProvider);
    await repo.updatePosition(current.id, position);

    // Lokalen Zustand aktualisieren
    state = AsyncValue.data(current.copyWith(lastPosition: position));
  }
}

/// Provider fuer [ActiveMediaNotifier].
final activeMediaNotifierProvider =
    AsyncNotifierProvider<ActiveMediaNotifier, MediaItem?>(
  ActiveMediaNotifier.new,
);

/// StreamProvider fuer Lesezeichen eines bestimmten Mediums.
final mediaBookmarksProvider =
    StreamProvider.family<List<Bookmark>, String>((ref, mediaItemId) {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.watchBookmarks(mediaItemId);
});
