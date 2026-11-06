import 'package:flutter/material.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_theme.dart';

/// Stellt sicher, dass das umschlossene Widget eine interaktive Mindest-Trefferflaeche
/// von mindestens 48x48 dp gemaess Bedtime-Barrierefreiheitsrichtlinien aufweist.
class BedtimeTouchTarget extends StatelessWidget {
  const BedtimeTouchTarget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minWidth = AmoledTheme.minTouchTargetSize,
    this.minHeight = AmoledTheme.minTouchTargetSize,
    this.borderRadius = 12.0,
    this.tooltip,
  });

  /// Das sichtbare Child-Widget.
  final Widget child;

  /// Optionaler Klick-Handler.
  final VoidCallback? onTap;

  /// Optionaler Long-Press-Handler.
  final VoidCallback? onLongPress;

  /// Mindestbreite der interaktiven Touch-Flaeche (Standard: 48 dp).
  final double minWidth;

  /// Mindesthoehe der interaktiven Touch-Flaeche (Standard: 48 dp).
  final double minHeight;

  /// Radius fuer den Touch-Effekt.
  final double borderRadius;

  /// Optionaler Barrierefreiheits-Tooltip.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      child: Center(
        child: child,
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AmoledColors.touchOverlay,
          highlightColor: AmoledColors.touchOverlay,
          child: content,
        ),
      );
    }

    if (tooltip != null) {
      content = Tooltip(
        message: tooltip!,
        child: content,
      );
    }

    return content;
  }
}

/// Spezieller Bedtime Icon-Button mit garantierter Mindestflaeche von 48x48 dp.
class BedtimeIconButton extends StatelessWidget {
  const BedtimeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AmoledColors.textPrimary,
    this.iconSize = 24.0,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final double iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return BedtimeTouchTarget(
      onTap: onPressed,
      tooltip: tooltip,
      child: Container(
        width: AmoledTheme.minTouchTargetSize,
        height: AmoledTheme.minTouchTargetSize,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: onPressed != null ? color : AmoledColors.disabled,
        ),
      ),
    );
  }
}

/// Primaerer Bedtime-Aktionsbutton mit grosser, blendfreier Touch-Flaeche.
class BedtimeActionButton extends StatelessWidget {
  const BedtimeActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isAccent = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final bg =
        isAccent ? AmoledColors.amberAccent : AmoledColors.surfaceElevated;
    final fg = isAccent ? AmoledColors.pureBlack : AmoledColors.textPrimary;
    final border = isAccent ? Colors.transparent : AmoledColors.divider;

    return BedtimeTouchTarget(
      minHeight: 52.0,
      minWidth: 120.0,
      onTap: onPressed,
      borderRadius: 16.0,
      child: Container(
        height: 52.0,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: onPressed != null ? bg : AmoledColors.disabled,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20.0, color: fg),
              const SizedBox(width: 8.0),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
