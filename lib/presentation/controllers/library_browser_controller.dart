import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/media_repository.dart';
import '../../domain/models/media_item.dart';
import '../providers/repository_providers.dart';
import '../state/library_browser_state.dart';

/// Controller fuer die Medienbibliothek mit Volltextsuche, Filterchips
/// und hierarchischer Gruppierung (Autor -> Alben -> Tracks).
class LibraryBrowserController extends Notifier<LibraryBrowserState> {
  LibraryBrowserController({
    MediaRepository? mediaRepoOverride,
  }) : _mediaRepoOverride = mediaRepoOverride;

  final MediaRepository? _mediaRepoOverride;

  MediaRepository get _mediaRepo =>
      _mediaRepoOverride ?? ref.read(mediaRepositoryProvider);

  StreamSubscription<List<MediaItem>>? _mediaSub;

  @override
  LibraryBrowserState build() {
    _initSubscription();
    ref.onDispose(_cleanup);
    return const LibraryBrowserState(isLoading: true);
  }

  void _initSubscription() {
    _mediaSub = _mediaRepo.watchAllMedia().listen((items) {
      _applyFilteringAndGrouping(rawItems: items);
    });
  }

  void _cleanup() {
    _mediaSub?.cancel();
    _mediaSub = null;
  }

  /// Aktualisiert den Volltext-Suchbegriff.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilteringAndGrouping();
  }

  /// Setzt den aktiven Filterchip.
  void setFilter(LibraryFilterChipType filter) {
    state = state.copyWith(activeFilter: filter);
    _applyFilteringAndGrouping();
  }

  /// Aendert die Sortierreihenfolge.
  void setSortOrder(LibrarySortOrder order) {
    state = state.copyWith(sortOrder: order);
    _applyFilteringAndGrouping();
  }

  void _applyFilteringAndGrouping({List<MediaItem>? rawItems}) {
    final sourceList = rawItems ?? state.items;
    final query = state.searchQuery.trim().toLowerCase();
    final filter = state.activeFilter;

    // 1. Filtern nach Suche und Kategorie
    var filtered = sourceList.where((item) {
      // Suchfilter (Titel, Autor, Album)
      if (query.isNotEmpty) {
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesAuthor =
            item.author?.toLowerCase().contains(query) ?? false;
        final matchesAlbum = item.album?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesAuthor && !matchesAlbum) {
          return false;
        }
      }

      // Filterchip
      switch (filter) {
        case LibraryFilterChipType.all:
          return true;
        case LibraryFilterChipType.audiobooks:
          return item.source.isLocal &&
              !item.extraMetadata.containsKey('podcast_title');
        case LibraryFilterChipType.podcasts:
          return item.extraMetadata.containsKey('podcast_title');
        case LibraryFilterChipType.youtube:
          return !item.source.isLocal &&
              !item.extraMetadata.containsKey('podcast_title');
        case LibraryFilterChipType.offlineOnly:
          return item.source.isLocal;
      }
    }).toList();

    // 2. Sortieren
    switch (state.sortOrder) {
      case LibrarySortOrder.authorAsc:
        filtered.sort((a, b) {
          final authorComp = (a.author ?? '')
              .toLowerCase()
              .compareTo((b.author ?? '').toLowerCase());
          if (authorComp != 0) return authorComp;
          final albumComp = (a.album ?? '')
              .toLowerCase()
              .compareTo((b.album ?? '').toLowerCase());
          if (albumComp != 0) return albumComp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case LibrarySortOrder.titleAsc:
        filtered.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySortOrder.durationDesc:
        filtered
            .sort((a, b) => (b.durationMs ?? 0).compareTo(a.durationMs ?? 0));
        break;
      case LibrarySortOrder.recent:
        // Nach ID sortieren
        filtered.sort((a, b) => b.id.compareTo(a.id));
        break;
    }

    // 3. Hierarchische Gruppierung: Autor -> Alben/Buecher -> Tracks
    final grouped = _groupMediaHierarchically(filtered);

    state = state.copyWith(
      items: sourceList,
      filteredItems: filtered,
      groupedByAuthor: grouped,
      isLoading: false,
    );
  }

  List<AuthorGroup> _groupMediaHierarchically(List<MediaItem> items) {
    final Map<String, Map<String, List<MediaItem>>> map = {};

    for (final item in items) {
      final author = item.author?.trim();
      final authorKey =
          (author != null && author.isNotEmpty) ? author : 'Unbekannter Autor';

      final album = item.album?.trim();
      final albumKey =
          (album != null && album.isNotEmpty) ? album : 'Einzelne Titel';

      map.putIfAbsent(authorKey, () => {});
      map[authorKey]!.putIfAbsent(albumKey, () => []);
      map[authorKey]![albumKey]!.add(item);
    }

    final authorGroups = <AuthorGroup>[];
    for (final authorEntry in map.entries) {
      final albumGroups = <AlbumGroup>[];
      for (final albumEntry in authorEntry.value.entries) {
        albumGroups.add(
          AlbumGroup(
            albumTitle: albumEntry.key,
            items: albumEntry.value,
          ),
        );
      }
      authorGroups.add(
        AuthorGroup(
          authorName: authorEntry.key,
          albums: albumGroups,
        ),
      );
    }

    return authorGroups;
  }
}
