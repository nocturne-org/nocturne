import '../../domain/models/media_item.dart';

/// Filter-Kategorien fuer den Library Browser.
enum LibraryFilterChipType {
  all,
  audiobooks,
  podcasts,
  youtube,
  offlineOnly,
}

/// Sortierreihenfolgen fuer Medieninhalte.
enum LibrarySortOrder {
  authorAsc,
  titleAsc,
  durationDesc,
  recent,
}

/// Domaenen-Hierarchie: Ein Album oder Buch eines Autors mit zugehoerigen Tracks.
class AlbumGroup {
  const AlbumGroup({
    required this.albumTitle,
    required this.items,
  });

  final String albumTitle;
  final List<MediaItem> items;

  int get totalDurationMs =>
      items.fold<int>(0, (sum, item) => sum + (item.durationMs ?? 0));

  int get trackCount => items.length;
}

/// Domaenen-Hierarchie: Ein Autor mit seinen Buechern / Alben.
class AuthorGroup {
  const AuthorGroup({
    required this.authorName,
    required this.albums,
  });

  final String authorName;
  final List<AlbumGroup> albums;

  int get totalTracks =>
      albums.fold<int>(0, (sum, album) => sum + album.trackCount);
}

/// Unveraenderlicher Zustand des Library Browsers.
class LibraryBrowserState {
  const LibraryBrowserState({
    this.searchQuery = '',
    this.activeFilter = LibraryFilterChipType.all,
    this.sortOrder = LibrarySortOrder.authorAsc,
    this.items = const [],
    this.filteredItems = const [],
    this.groupedByAuthor = const [],
    this.isLoading = false,
  });

  /// Aktueller Volltext-Suchbegriff.
  final String searchQuery;

  /// Aktiver Filterchip.
  final LibraryFilterChipType activeFilter;

  /// Aktuelle Sortierung.
  final LibrarySortOrder sortOrder;

  /// Alle ungefilterten Medien aus der Datenbank.
  final List<MediaItem> items;

  /// Nach Suche und Filterchip gefilterte Liste.
  final List<MediaItem> filteredItems;

  /// Hierarchisch strukturierte Liste: Autor -> Alben/Buecher -> Tracks.
  final List<AuthorGroup> groupedByAuthor;

  /// Ladezustand.
  final bool isLoading;

  LibraryBrowserState copyWith({
    String? searchQuery,
    LibraryFilterChipType? activeFilter,
    LibrarySortOrder? sortOrder,
    List<MediaItem>? items,
    List<MediaItem>? filteredItems,
    List<AuthorGroup>? groupedByAuthor,
    bool? isLoading,
  }) {
    return LibraryBrowserState(
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      sortOrder: sortOrder ?? this.sortOrder,
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      groupedByAuthor: groupedByAuthor ?? this.groupedByAuthor,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() =>
      'LibraryBrowserState(filter: $activeFilter, query: "$searchQuery", items: ${filteredItems.length})';
}
