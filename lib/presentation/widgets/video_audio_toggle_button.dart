import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/video_mode_controller.dart';
import '../state/video_playback_state.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';

/// Minimalistischer AMOLED-Umschaltknopf zwischen Reinaudio- und Videomodus.
/// Wechselt ohne Abspielunterbrechung zwischen den beiden Medienmodi.
class VideoAudioToggleButton extends StatelessWidget {
  const VideoAudioToggleButton({
    super.key,
    required this.state,
    required this.controller,
  });

  final VideoPlaybackState state;
  final VideoModeController controller;

  @override
  Widget build(BuildContext context) {
    if (!state.isVideoAvailable) {
      return const SizedBox.shrink();
    }

    final isVideo = state.isVideo;

    return Semantics(
      button: true,
      label: isVideo ? 'In reinen Audio-Modus wechseln' : 'In Video-Modus wechseln',
      child: InkWell(
        onTap: () => controller.toggleMode(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AmoledColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVideo ? AmoledColors.cyanAccent : AmoledColors.amberAccent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.videocam_rounded : Icons.headphones_rounded,
                color: isVideo ? AmoledColors.cyanAccent : AmoledColors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isVideo ? 'VIDEO' : 'AUDIO',
                style: AmoledTypography.caption.copyWith(
                  color: isVideo ? AmoledColors.cyanAccent : AmoledColors.amberAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
