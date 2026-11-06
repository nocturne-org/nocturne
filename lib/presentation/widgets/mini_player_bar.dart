import 'package:flutter/material.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_theme.dart';
import '../theme/amoled_typography.dart';
import 'bedtime_touch_target.dart';

/// Persistent Spotify-style mini player bar displayed above bottom navigation.
class MiniPlayerBar extends StatelessWidget {
  final String title;
  final String author;
  final bool isPlaying;
  final Duration position;
  final Duration totalDuration;
  final VoidCallback onTap;
  final VoidCallback onTogglePlayPause;

  const MiniPlayerBar({
    super.key,
    required this.title,
    required this.author,
    required this.isPlaying,
    required this.position,
    required this.totalDuration,
    required this.onTap,
    required this.onTogglePlayPause,
  });

  double _calculateProgress() {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    final p = position.inMilliseconds / totalDuration.inMilliseconds;
    return p.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();

    return Material(
      color: AmoledColors.surfaceElevated,
      child: InkWell(
        key: const Key('mini_player_tap_area'),
        onTap: onTap,
        child: Container(
          height: AmoledTheme.miniPlayerHeight,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AmoledColors.divider,
                width: 1.0,
              ),
            ),
          ),
          child: Stack(
            children: [
              // 1. Main row with media metadata and play/pause
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    // Media thumbnail / icon container
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: AmoledColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AmoledColors.divider,
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.headphones_rounded,
                        color: AmoledColors.midnightBlue,
                        size: 22.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),

                    // Title & Author
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmoledTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AmoledColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmoledTypography.caption.copyWith(
                              color: AmoledColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play / Pause button
                    BedtimeTouchTarget(
                      key: const Key('mini_player_play_pause_button'),
                      minWidth: 48.0,
                      minHeight: 48.0,
                      borderRadius: 24.0,
                      tooltip: isPlaying ? 'Pause' : 'Play',
                      onTap: onTogglePlayPause,
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: const BoxDecoration(
                          color: AmoledColors.midnightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 24.0,
                          color: AmoledColors.pureBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Subtle progress line along the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  key: const Key('mini_player_progress_bar'),
                  value: progress,
                  minHeight: 2.0,
                  backgroundColor: AmoledColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AmoledColors.midnightBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
