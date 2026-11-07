import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/database/daos/media_dao.dart';
import '../providers/database_provider.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_theme.dart';
import '../theme/amoled_typography.dart';

/// Modal bottom sheet fuer die Auswahl oder Erstellung von Playlists.
class PlaylistPickerSheet extends ConsumerStatefulWidget {
  final String mediaItemId;
  final String itemTitle;
  final MediaDao? mediaDao;

  const PlaylistPickerSheet({
    super.key,
    required this.mediaItemId,
    required this.itemTitle,
    this.mediaDao,
  });

  /// Zeigt das PlaylistPickerSheet als modales Bottom Sheet an.
  static Future<void> show({
    required BuildContext context,
    required String mediaItemId,
    required String itemTitle,
    MediaDao? mediaDao,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AmoledColors.pureBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AmoledTheme.sheetRadius),
        ),
      ),
      builder: (ctx) => PlaylistPickerSheet(
        mediaItemId: mediaItemId,
        itemTitle: itemTitle,
        mediaDao: mediaDao,
      ),
    );
  }

  @override
  ConsumerState<PlaylistPickerSheet> createState() =>
      _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends ConsumerState<PlaylistPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PlaylistEntry> _playlists = [];
  bool _isLoading = true;

  MediaDao get _dao => widget.mediaDao ?? ref.read(mediaDaoProvider);

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final list = await _dao.getPlaylistsSortedByRecent();
    if (mounted) {
      setState(() {
        _playlists = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addToExistingPlaylist(PlaylistEntry playlist) async {
    unawaited(HapticFeedback.lightImpact());
    await _dao.addItemsToPlaylist(playlist.id, [widget.mediaItemId]);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${widget.itemTitle}" to "${playlist.name}".'),
          backgroundColor: AmoledColors.surfaceElevated,
        ),
      );
    }
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AmoledColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AmoledColors.divider),
        ),
        title: Text(
          'Neue Playlist',
          style: AmoledTypography.titleLarge.copyWith(
            color: AmoledColors.textPrimary,
          ),
        ),
        content: TextField(
          key: const Key('new_playlist_name_input'),
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AmoledColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist-Name',
            hintStyle: const TextStyle(color: AmoledColors.textTertiary),
            filled: true,
            fillColor: AmoledColors.surfaceCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AmoledColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AmoledColors.violet),
            ),
          ),
        ),
        actions: [
          SizedBox(
            height: 48.0,
            child: TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(
                'Abbrechen',
                style: TextStyle(color: AmoledColors.textSecondary),
              ),
            ),
          ),
          SizedBox(
            height: 48.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AmoledColors.violet,
                foregroundColor: AmoledColors.pureBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(dialogCtx).pop();
                  unawaited(HapticFeedback.lightImpact());
                  final created = await _dao.createPlaylist(name);
                  await _dao.addItemsToPlaylist(created.id, [widget.mediaItemId]);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added "${widget.itemTitle}" to new playlist "$name".',
                        ),
                        backgroundColor: AmoledColors.surfaceElevated,
                      ),
                    );
                  }
                }
              },
              child: const Text('Erstellen'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredPlaylists = _searchQuery.isEmpty
        ? _playlists
        : _playlists
            .where(
              (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AmoledColors.disabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Text(
                'Zu Playlist hinzufuegen',
                style: AmoledTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AmoledColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.itemTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmoledTypography.bodyMedium.copyWith(
                  color: AmoledColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Search field
              TextField(
                key: const Key('playlist_picker_search_field'),
                controller: _searchController,
                style: const TextStyle(color: AmoledColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Playlists durchsuchen...',
                  hintStyle: const TextStyle(color: AmoledColors.textTertiary),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AmoledColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AmoledColors.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AmoledColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AmoledColors.midnightBlue),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Create new playlist action
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48.0),
                child: OutlinedButton.icon(
                  key: const Key('create_new_playlist_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AmoledColors.violet,
                    side: const BorderSide(color: AmoledColors.violet),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Neue Playlist erstellen'),
                  onPressed: _showCreatePlaylistDialog,
                ),
              ),
              const SizedBox(height: 12),

              // Playlist list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AmoledColors.midnightBlue,
                        ),
                      )
                    : filteredPlaylists.isEmpty
                        ? Center(
                            child: Text(
                              _playlists.isEmpty
                                  ? 'Noch keine Playlists vorhanden.'
                                  : 'Keine passende Playlist gefunden.',
                              style: AmoledTypography.bodyMedium.copyWith(
                                color: AmoledColors.textTertiary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredPlaylists.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: AmoledColors.divider, height: 1),
                            itemBuilder: (context, index) {
                              final playlist = filteredPlaylists[index];
                              return ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 48.0),
                                child: ListTile(
                                  key: Key('playlist_entry_${playlist.id}'),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  leading: const Icon(
                                    Icons.playlist_play_rounded,
                                    color: AmoledColors.midnightBlue,
                                    size: 28,
                                  ),
                                  title: Text(
                                    playlist.name,
                                    style: AmoledTypography.bodyLarge.copyWith(
                                      color: AmoledColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AmoledColors.textTertiary,
                                    size: 20,
                                  ),
                                  onTap: () => _addToExistingPlaylist(playlist),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
