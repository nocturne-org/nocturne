import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/amoled_colors.dart';

/// Interactive bedtime transport button that triggers a single 15s jump on tap
/// and continuous 5s seeking ticks every 200ms when held down.
class SeekButton extends StatefulWidget {
  final bool isForward;
  final VoidCallback onSingleSeek;
  final VoidCallback onContinuousTick;
  final String tooltip;
  final double size;

  const SeekButton({
    super.key,
    required this.isForward,
    required this.onSingleSeek,
    required this.onContinuousTick,
    required this.tooltip,
    this.size = 64.0,
  });

  @override
  State<SeekButton> createState() => _SeekButtonState();
}

class _SeekButtonState extends State<SeekButton> {
  Timer? _continuousTimer;

  @override
  void dispose() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
    super.dispose();
  }

  void _startContinuousSeeking() {
    _continuousTimer?.cancel();
    HapticFeedback.mediumImpact();
    // Immediate first continuous tick
    widget.onContinuousTick();
    _continuousTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      HapticFeedback.selectionClick();
      widget.onContinuousTick();
    });
  }

  void _stopContinuousSeeking() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSingleSeek,
        onLongPressStart: (_) => _startContinuousSeeking(),
        onLongPressEnd: (_) => _stopContinuousSeeking(),
        onLongPressCancel: () => _stopContinuousSeeking(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.size + 8.0,
            minHeight: widget.size + 8.0,
          ),
          child: Center(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: AmoledColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AmoledColors.divider,
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isForward ? Icons.redo_rounded : Icons.undo_rounded,
                    size: 26.0,
                    color: AmoledColors.textPrimary,
                  ),
                  const SizedBox(height: 2.0),
                  const Text(
                    '15s',
                    style: TextStyle(
                      color: AmoledColors.textSecondary,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
