import 'package:flutter/material.dart';
import '../../data/datasources/database/daos/media_dao.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';

/// Modal dialog for adding a media item or stream to a playlist.
class AddToPlaylistDialog extends StatefulWidget {
  final String mediaItemId;
  final String itemTitle;
  final MediaDao mediaDao;

  const AddToPlaylistDialog({
    super.key,
    required this.mediaItemId,
    required this.itemTitle,
    required this.mediaDao,
  });

  /// Displays the AddToPlaylistDialog.
  static Future<void> show({
    required BuildContext context,
    required String mediaItemId,
    required String itemTitle,
    required MediaDao mediaDao,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AddToPlaylistDialog(
        mediaItemId: mediaItemId,
        itemTitle: itemTitle,
        mediaDao: mediaDao,
      ),
    );
  }

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newPlaylistController = TextEditingController();
  List<PlaylistEntry> _allPlaylists = [];
  bool _isLoading = true;
  bool _isCreatingNew = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newPlaylistController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final list = await widget.mediaDao.getPlaylistsSortedByRecent();
    if (mounted) {
      setState(() {
        _allPlaylists = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewPlaylist() async {
    final name = _newPlaylistController.text.trim();
    if (name.isEmpty) return;

    final created = await widget.mediaDao.createPlaylist(name);
    await widget.mediaDao.addItemsToPlaylist(created.id, [widget.mediaItemId]);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${widget.itemTitle}" to new playlist "$name".'),
          backgroundColor: AmoledColors.surfaceElevated,
        ),
      );
    }
  }

  Future<void> _addToExistingPlaylist(PlaylistEntry playlist) async {
    await widget.mediaDao.addItemsToPlaylist(playlist.id, [widget.mediaItemId]);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to "${playlist.name}".'),
          backgroundColor: AmoledColors.surfaceElevated,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _allPlaylists
        : _allPlaylists.where((p) => p.name.toLowerCase().contains(query)).toList();

    return AlertDialog(
      backgroundColor: AmoledColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AmoledColors.divider),
      ),
      title: Text(
        'Add to Playlist',
        style: AmoledTypography.titleLarge.copyWith(
          color: AmoledColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search filter
            TextField(
              controller: _searchController,
              style: AmoledTypography.bodyMedium.copyWith(color: AmoledColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search playlists...',
                hintStyle: AmoledTypography.bodyMedium.copyWith(color: AmoledColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AmoledColors.textSecondary),
                filled: true,
                fillColor: AmoledColors.surfaceCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AmoledColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AmoledColors.midnightBlue),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Inline "+ New Playlist" button / row
            if (!_isCreatingNew)
              TextButton.icon(
                key: const Key('add_to_playlist_new_button'),
                icon: const Icon(Icons.add_rounded, color: AmoledColors.midnightBlue),
                label: const Text(
                  '+ New Playlist',
                  style: TextStyle(
                    color: AmoledColors.midnightBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: () {
                  setState(() {
                    _isCreatingNew = true;
                  });
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPlaylistController,
                      autofocus: true,
                      style: AmoledTypography.bodyMedium.copyWith(color: AmoledColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Playlist name...',
                        hintStyle: AmoledTypography.bodyMedium.copyWith(color: AmoledColors.textTertiary),
                        filled: true,
                        fillColor: AmoledColors.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AmoledColors.divider),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('confirm_create_playlist_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AmoledColors.midnightBlue,
                      foregroundColor: AmoledColors.pureBlack,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _createNewPlaylist,
                    child: const Text('Create'),
                  ),
                ],
              ),

            const Divider(color: AmoledColors.divider, height: 16),

            // Scrollable playlist list sorted by addedAt DESC
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AmoledColors.midnightBlue),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              'No playlists found.',
                              style: AmoledTypography.bodyMedium.copyWith(color: AmoledColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(color: AmoledColors.divider, height: 1),
                          itemBuilder: (context, index) {
                            final playlist = filtered[index];
                            return ListTile(
                              key: Key('playlist_item_${playlist.id}'),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                              leading: const Icon(
                                Icons.playlist_play_rounded,
                                color: AmoledColors.midnightBlue,
                              ),
                              title: Text(
                                playlist.name,
                                style: const TextStyle(
                                  color: AmoledColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                playlist.kind,
                                style: const TextStyle(
                                  color: AmoledColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                              onTap: () => _addToExistingPlaylist(playlist),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: AmoledColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
