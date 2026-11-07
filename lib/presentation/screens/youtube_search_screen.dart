import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/youtube_search_service.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/playlist_picker_sheet.dart';

/// Screen fuer die Suche und Erkundung von YouTube- und Web-Audio-Streams.
class YouTubeSearchScreen extends ConsumerStatefulWidget {
  final YouTubeSearchService? searchService;
  final ValueChanged<WebStreamSearchResult>? onPlayResult;

  const YouTubeSearchScreen({
    super.key,
    this.searchService,
    this.onPlayResult,
  });

  @override
  ConsumerState<YouTubeSearchScreen> createState() =>
      _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends ConsumerState<YouTubeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final YouTubeSearchService _service;

  List<WebStreamSearchResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.searchService ?? YouTubeSearchService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final res = await _service.search(trimmed);
      if (mounted) {
        setState(() {
          _results = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AmoledColors.pureBlack,
      appBar: AppBar(
        backgroundColor: AmoledColors.pureBlack,
        elevation: 0,
        title: Text(
          'Web-Streams & YouTube',
          style: AmoledTypography.titleLarge.copyWith(
            color: AmoledColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Suchleiste
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('youtube_search_input'),
                      controller: _searchController,
                      style: const TextStyle(color: AmoledColors.textPrimary),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _performSearch,
                      decoration: InputDecoration(
                        hintText: 'Suchbegriff oder URL eingeben...',
                        hintStyle:
                            const TextStyle(color: AmoledColors.textTertiary),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AmoledColors.textTertiary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: AmoledColors.textTertiary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AmoledColors.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AmoledColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AmoledColors.midnightBlue,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    child: IconButton(
                      key: const Key('youtube_search_submit_button'),
                      style: IconButton.styleFrom(
                        backgroundColor: AmoledColors.midnightBlue,
                        foregroundColor: AmoledColors.pureBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () =>
                          _performSearch(_searchController.text),
                    ),
                  ),
                ],
              ),
            ),

            // Inhaltsbereich
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('youtube_search_loading_indicator'),
          color: AmoledColors.midnightBlue,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AmoledColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Fehler bei der Suche',
                style: AmoledTypography.titleMedium.copyWith(
                  color: AmoledColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AmoledTypography.bodySmall.copyWith(
                  color: AmoledColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        key: const Key('youtube_search_initial_state'),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                size: 64,
                color: AmoledColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Web-Streams & YouTube durchsuchen',
                style: AmoledTypography.titleLarge.copyWith(
                  color: AmoledColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gib einen Suchbegriff oder eine Video-URL ein, um passende Streams abzuspielen.',
                textAlign: TextAlign.center,
                style: AmoledTypography.bodyMedium.copyWith(
                  color: AmoledColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        key: const Key('youtube_search_empty_state'),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AmoledColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'Keine Treffer gefunden',
                style: AmoledTypography.titleMedium.copyWith(
                  color: AmoledColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Versuche einen anderen Suchbegriff oder eine direkte Video-URL.',
                textAlign: TextAlign.center,
                style: AmoledTypography.bodySmall.copyWith(
                  color: AmoledColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _results[index];
        return _buildResultCard(item);
      },
    );
  }

  Widget _buildResultCard(WebStreamSearchResult item) {
    return Card(
      key: Key('youtube_result_card_${item.videoId}'),
      color: AmoledColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AmoledColors.divider),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onPlayResult?.call(item),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90,
                  height: 60,
                  color: AmoledColors.surfaceElevated,
                  child: Image.network(
                    item.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.music_video_rounded,
                        color: AmoledColors.textTertiary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Channel, Duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AmoledTypography.titleMedium.copyWith(
                        color: AmoledColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AmoledTypography.bodySmall.copyWith(
                        color: AmoledColors.textSecondary,
                      ),
                    ),
                    if (item.duration != null &&
                        item.duration! > Duration.zero) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(item.duration!),
                        style: AmoledTypography.bodySmall.copyWith(
                          color: AmoledColors.midnightBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons (Favorite & Add to Playlist)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FavoriteHeartButton(
                    mediaItemId: item.videoId,
                    size: 22.0,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    child: IconButton(
                      key: Key('add_to_playlist_${item.videoId}'),
                      icon: const Icon(
                        Icons.playlist_add_rounded,
                        color: AmoledColors.midnightBlue,
                        size: 24,
                      ),
                      tooltip: 'Zu Playlist hinzufuegen',
                      onPressed: () {
                        PlaylistPickerSheet.show(
                          context: context,
                          mediaItemId: item.videoId,
                          itemTitle: item.title,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
