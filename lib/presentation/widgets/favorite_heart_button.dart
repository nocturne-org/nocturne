import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../theme/amoled_colors.dart';

/// Barrierefreier, reaktiver Favoriten-Button mit direktem Drift SQLite-Stream.
class FavoriteHeartButton extends ConsumerWidget {
  final String mediaItemId;
  final double size;
  final VoidCallback? onToggled;

  const FavoriteHeartButton({
    super.key,
    required this.mediaItemId,
    this.size = 24.0,
    this.onToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav = favoritesAsync.value?.contains(mediaItemId) ?? false;

    return Semantics(
      label: isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufuegen',
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
        child: IconButton(
          key: Key('favorite_heart_$mediaItemId'),
          iconSize: size,
          splashRadius: 24.0,
          icon: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? AmoledColors.violet : AmoledColors.textTertiary,
          ),
          onPressed: () async {
            unawaited(HapticFeedback.lightImpact());
            final dao = ref.read(mediaDaoProvider);
            await dao.toggleFavorite(mediaItemId);
            onToggled?.call();
          },
        ),
      ),
    );
  }
}
