import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/media_item.dart';
import '../providers/queue_providers.dart';
import '../state/unified_queue_state.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';

/// Ansicht fuer die einheitliche Abspiel-Warteschlange (Unified Playback Queue).
/// AMOLED-optimiert mit Pure-Black-Hintergrund, Drag-and-Drop Reordering
/// und Wisch-Loeschen fuer Audiobuecher, Podcasts und YouTube-Streams.
class UnifiedQueueView extends ConsumerWidget {
  const UnifiedQueueView({
    super.key,
    this.onClose,
  });

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(unifiedQueueControllerProvider);
    final controller = ref.read(unifiedQueueControllerProvider.notifier);

    return Container(
      color: AmoledColors.pureBlack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header mit Schliessen- und Steuerleiste
          _buildHeader(context, queueState, controller),
          const Divider(color: AmoledColors.divider, height: 1),

          // Liste oder Leerer Zustand
          Expanded(
            child: queueState.items.isEmpty
                ? _buildEmptyState()
                : _buildReorderableList(queueState, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UnifiedQueueState state,
    dynamic controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.queue_music_rounded,
            color: AmoledColors.midnightBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warteschlange',
                  style: AmoledTypography.headingMedium,
                ),
                Text(
                  '${state.totalTracks} Titel',
                  style: AmoledTypography.caption,
                ),
              ],
            ),
          ),
          if (state.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              color: AmoledColors.textSecondary,
              tooltip: 'Warteschlange leeren',
              onPressed: () => controller.clearQueue(),
            ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: AmoledColors.textPrimary,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.nightlight_round,
            color: AmoledColors.disabled,
            size: 48,
          ),
          const SizedBox(width: 0, height: 16),
          Text(
            'Warteschlange ist leer',
            style: AmoledTypography.headingMedium.copyWith(
              color: AmoledColors.textSecondary,
            ),
          ),
          const SizedBox(width: 0, height: 8),
          Text(
            'Füge Audiobücher, Podcasts oder YouTube-Titel hinzu.',
            style: AmoledTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(
    UnifiedQueueState state,
    dynamic controller,
  ) {
    return ReorderableListView.builder(
      itemCount: state.items.length,
      onReorder: (oldIndex, newIndex) {
        controller.reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = state.items[index];
        final isPlaying = index == state.currentIndex;

        return Dismissible(
          key: ValueKey('queue_item_${item.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AmoledColors.error.withOpacity(0.8),
            child: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          onDismissed: (_) {
            controller.removeItem(index);
          },
          child: _QueueItemTile(
            item: item,
            index: index,
            isPlaying: isPlaying,
            onTap: () => controller.playTrackAtIndex(index),
          ),
        );
      },
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
    required this.item,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  final MediaItem item;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeBadge = _getBadgeLabel(item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            isPlaying ? AmoledColors.surfaceElevated : AmoledColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPlaying ? AmoledColors.midnightBlue : AmoledColors.divider,
          width: isPlaying ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onTap,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying)
              const Icon(
                Icons.play_arrow_rounded,
                color: AmoledColors.midnightBlue,
                size: 24,
              )
            else
              Text(
                '${index + 1}',
                style: AmoledTypography.caption.copyWith(
                  color: AmoledColors.textTertiary,
                ),
              ),
            const SizedBox(width: 8),
            _buildLeadingCover(item),
          ],
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AmoledTypography.bodyMedium.copyWith(
            color:
                isPlaying ? AmoledColors.midnightBlue : AmoledColors.textPrimary,
            fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AmoledColors.pureBlack,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getBadgeColor(typeBadge),
                  width: 0.8,
                ),
              ),
              child: Text(
                typeBadge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getBadgeColor(typeBadge),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (item.author ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmoledTypography.caption,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.drag_handle_rounded,
          color: AmoledColors.disabled,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLeadingCover(MediaItem item) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AmoledColors.pureBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AmoledColors.divider),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: AmoledColors.textSecondary,
        size: 20,
      ),
    );
  }

  String _getBadgeLabel(MediaItem item) {
    if (item.source.isLocal) {
      return 'AUDIOBUCH';
    }
    if (item.extraMetadata.containsKey('podcast_title')) {
      return 'PODCAST';
    }
    return 'YOUTUBE';
  }

  Color _getBadgeColor(String badge) {
    switch (badge) {
      case 'AUDIOBUCH':
        return AmoledColors.midnightBlue;
      case 'PODCAST':
        return AmoledColors.violet;
      case 'YOUTUBE':
        return const Color(0xFFFF5252);
      default:
        return AmoledColors.textSecondary;
    }
  }
}
