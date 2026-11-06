import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/media_item.dart';
import '../providers/library_providers.dart';
import '../providers/queue_providers.dart';
import '../state/library_browser_state.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';

/// Bildschirm fuer die Medienbibliothek mit Volltextsuche, Filterchips,
/// hierarchischer Darstellung (Autor -> Alben -> Tracks) und Schnellzugriff auf die Queue.
class LibraryBrowserScreen extends ConsumerWidget {
  const LibraryBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryBrowserControllerProvider);
    final controller = ref.read(libraryBrowserControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AmoledColors.pureBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Suchfeld
            _buildSearchBar(context, state, controller),

            // Filterchips Bar
            _buildFilterChips(context, state, controller),

            const Divider(color: AmoledColors.divider, height: 1),

            // Medieninhalte
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AmoledColors.amberAccent,
                      ),
                    )
                  : state.groupedByAuthor.isEmpty
                      ? _buildEmptyState(state)
                      : _buildHierarchyList(context, ref, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    LibraryBrowserState state,
    LibraryBrowserController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AmoledColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AmoledColors.divider),
        ),
        child: TextField(
          style: AmoledTypography.bodyLarge,
          cursorColor: AmoledColors.amberAccent,
          decoration: InputDecoration(
            hintText: 'Bibliothek durchsuchen...',
            hintStyle: AmoledTypography.bodyMedium.copyWith(
              color: AmoledColors.textTertiary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AmoledColors.amberAccent,
            ),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    color: AmoledColors.textSecondary,
                    onPressed: () => controller.setSearchQuery(''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (val) => controller.setSearchQuery(val),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    LibraryBrowserState state,
    LibraryBrowserController controller,
  ) {
    const filters = [
      (LibraryFilterChipType.all, 'Alle'),
      (LibraryFilterChipType.audiobooks, 'Hoerbuecher'),
      (LibraryFilterChipType.podcasts, 'Podcasts'),
      (LibraryFilterChipType.youtube, 'YouTube'),
      (LibraryFilterChipType.offlineOnly, 'Offline'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = state.activeFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : AmoledColors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AmoledColors.amberAccent,
              backgroundColor: AmoledColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AmoledColors.amberAccent : AmoledColors.divider,
                ),
              ),
              onSelected: (_) => controller.setFilter(f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(LibraryBrowserState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.library_music_rounded,
            color: AmoledColors.disabled,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            state.searchQuery.isNotEmpty
                ? 'Keine Treffer fuer "${state.searchQuery}"'
                : 'Keine Medien gefunden',
            style: AmoledTypography.headingMedium.copyWith(
              color: AmoledColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Passe deine Suchbegriffe oder Filterchips an.',
            style: AmoledTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyList(
    BuildContext context,
    WidgetRef ref,
    LibraryBrowserState state,
  ) {
    return ListView.builder(
      itemCount: state.groupedByAuthor.length,
      itemBuilder: (context, authorIdx) {
        final author = state.groupedByAuthor[authorIdx];

        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: state.searchQuery.isNotEmpty || state.groupedByAuthor.length == 1,
            collapsedIconColor: AmoledColors.textSecondary,
            iconColor: AmoledColors.amberAccent,
            leading: const CircleAvatar(
              backgroundColor: AmoledColors.surfaceElevated,
              child: Icon(Icons.person_rounded, color: AmoledColors.amberAccent),
            ),
            title: Text(
              author.authorName,
              style: AmoledTypography.headingMedium,
            ),
            subtitle: Text(
              '${author.albums.length} Alben / Buecher - ${author.totalTracks} Titel',
              style: AmoledTypography.caption,
            ),
            children: author.albums.map((album) {
              return _buildAlbumTile(context, ref, album);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAlbumTile(
    BuildContext context,
    WidgetRef ref,
    AlbumGroup album,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AmoledColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AmoledColors.divider),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        collapsedIconColor: AmoledColors.textTertiary,
        iconColor: AmoledColors.amberAccent,
        leading: const Icon(
          Icons.album_rounded,
          color: AmoledColors.textSecondary,
        ),
        title: Text(
          album.albumTitle,
          style: AmoledTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${album.trackCount} Tracks',
          style: AmoledTypography.caption,
        ),
        children: album.items.map((item) {
          return _buildTrackTile(context, ref, item);
        }).toList(),
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) {
    final queueController = ref.read(unifiedQueueControllerProvider.notifier);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        item.source.isLocal ? Icons.audiotrack_rounded : Icons.stream_rounded,
        color: item.source.isLocal
            ? AmoledColors.amberAccent
            : AmoledColors.cyanAccent,
        size: 20,
      ),
      title: Text(
        item.title,
        style: AmoledTypography.bodyMedium,
      ),
      subtitle: Text(
        _formatDuration(item.durationMs),
        style: AmoledTypography.caption,
      ),
      trailing: PopupMenuButton<String>(
        color: AmoledColors.surfaceElevated,
        icon: const Icon(Icons.more_vert_rounded, color: AmoledColors.textSecondary),
        onSelected: (action) {
          if (action == 'play_now') {
            queueController.addItem(item);
          } else if (action == 'play_next') {
            queueController.insertNext(item);
          } else if (action == 'add_queue') {
            queueController.addItem(item);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play_now',
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, color: AmoledColors.amberAccent, size: 20),
                SizedBox(width: 8),
                Text('Jetzt abspielen', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'play_next',
            child: Row(
              children: [
                Icon(Icons.playlist_play_rounded, color: AmoledColors.cyanAccent, size: 20),
                SizedBox(width: 8),
                Text('Als naechstes abspielen', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'add_queue',
            child: Row(
              children: [
                Icon(Icons.queue_rounded, color: AmoledColors.textPrimary, size: 20),
                SizedBox(width: 8),
                Text('Zur Warteschlange hinzufuegen', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final totalSec = ms ~/ 1000;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    final h = totalSec ~/ 3600;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
