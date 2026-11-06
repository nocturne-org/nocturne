import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/sleep_timer_state.dart';
import '../theme/amoled_colors.dart';

/// Grosser, kreisfoermiger Countdown-HUD fuer den Bedtime Sleep-Timer (TICK-027).
///
/// Bietet:
/// - Kreisfoermigen Fortschrittsbogen mit hohem Kontrast auf AMOLED-Schwarz.
/// - Grosse digitale Zeitanzeige (z. B. "24:18") in der Kreismitte.
/// - Klare Zustandshinweise bei Fade-Out und Grace-Period.
/// - One-Tap Interaktion zur Schnellaktivierung.
class SleepTimerCircularHud extends StatelessWidget {
  final SleepTimerState timerState;
  final VoidCallback? onTap;
  final double size;

  const SleepTimerCircularHud({
    super.key,
    required this.timerState,
    this.onTap,
    this.size = 230.0,
  });

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();
    final remainingText = _formatRemaining();
    final statusLabel = _buildStatusLabel();
    final arcColor = _getArcColor();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: 'Schlaftimer Restzeit $remainingText, $statusLabel',
        button: true,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hintergrund- und Fortschritts-Kreis
              CustomPaint(
                size: Size(size, size),
                painter: _CircularProgressPainter(
                  progress: progress,
                  strokeWidth: 10.0,
                  backgroundColor: AmoledColors.surfaceElevated,
                  progressColor: arcColor,
                ),
              ),
              // Zentrierte Textinhalte
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Grosser digitaler Countdown
                    Text(
                      remainingText,
                      style: const TextStyle(
                        color: AmoledColors.textPrimary,
                        fontSize: 38.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Status-Beschriftung
                    Text(
                      statusLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getStatusTextColor(),
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress() {
    if (!timerState.isActive && !timerState.isGracePeriod) {
      return 0.0;
    }
    if (timerState.isGracePeriod) {
      final remaining = timerState.gracePeriodRemaining.inMilliseconds;
      return (remaining / 120000.0).clamp(0.0, 1.0);
    }
    final total = timerState.totalDuration.inMilliseconds;
    if (total <= 0) return 0.0;
    final remaining = timerState.remainingDuration.inMilliseconds;
    return (remaining / total).clamp(0.0, 1.0);
  }

  String _formatRemaining() {
    if (timerState.isGracePeriod) {
      final s = timerState.gracePeriodRemaining.inSeconds;
      return '${s}s';
    }
    if (!timerState.isActive) {
      return 'Aus';
    }
    final totalSec = timerState.remainingDuration.inSeconds;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _buildStatusLabel() {
    if (timerState.isGracePeriod) {
      return 'Grace-Period (Schuetteln!)';
    }
    if (timerState.isFadingOut) {
      return 'Ausblendend...';
    }
    if (timerState.isActive) {
      return 'Schlaftimer aktiv';
    }
    return 'Timer starten';
  }

  Color _getArcColor() {
    if (timerState.isGracePeriod) {
      return AmoledColors.progressGrace;
    }
    if (timerState.isFadingOut) {
      return AmoledColors.progressFading;
    }
    if (timerState.isActive) {
      return AmoledColors.progressActive;
    }
    return AmoledColors.disabled;
  }

  Color _getStatusTextColor() {
    if (timerState.isGracePeriod) {
      return AmoledColors.progressGrace;
    }
    if (timerState.isFadingOut) {
      return AmoledColors.progressFading;
    }
    if (timerState.isActive) {
      return AmoledColors.textSecondary;
    }
    return AmoledColors.textTertiary;
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Hintergrund-Ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Fortschritts-Bogen (startet oben bei -90 Grad)
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
