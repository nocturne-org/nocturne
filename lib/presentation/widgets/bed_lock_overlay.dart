import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/amoled_colors.dart';

/// Vollbild-Touchsperre (Touch Lock) gemaess Nocturne-Spezifikation (TICK-028 & TICK-V2-02).
///
/// Schuetzt den Bedtime-Player vor versehentlichen Eingaben durch Bettdecke, Kissen
/// oder unwillkuerliche Koerperbewegungen im Halbschlaf.
///
/// Merkmale:
/// - 95% AMOLED-Bildschirmabdunklung fuer minimales Schlafzimmer-Licht.
/// - Blockiert ausnahmslos alle darunterliegenden Touch-Ereignisse.
/// - Entsperren erfordert eine bewusste Geste:
///   1. 2-Sekunden-Gedrueckthalten (Long-Press mit animiertem Fortschrittsring) ODER
///   2. Wischgeste nach oben (Swipe-Up).
class BedLockOverlay extends StatefulWidget {
  final bool isLocked;
  final VoidCallback onUnlock;
  final Widget child;

  const BedLockOverlay({
    super.key,
    required this.isLocked,
    required this.onUnlock,
    required this.child,
  });

  @override
  State<BedLockOverlay> createState() => _BedLockOverlayState();
}

class _BedLockOverlayState extends State<BedLockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _unlockAnimationController;
  Timer? _holdTimer;
  double _verticalDragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    // Exakt 2 Sekunden Haltedauer zum Entsperren gemaess Spezifikation
    _unlockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didUpdateWidget(covariant BedLockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLocked && widget.isLocked) {
      _verticalDragDistance = 0.0;
      _holdTimer?.cancel();
      _holdTimer = null;
      _unlockAnimationController.reset();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _unlockAnimationController.dispose();
    super.dispose();
  }

  void _triggerUnlock() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _verticalDragDistance = 0.0;
    HapticFeedback.mediumImpact();
    widget.onUnlock();
    _unlockAnimationController.reset();
  }

  void _startHolding() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _triggerUnlock();
    });
    _unlockAnimationController.forward();
  }

  void _cancelHolding() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_unlockAnimationController.status != AnimationStatus.completed) {
      _unlockAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Darunterliegender Inhalt (wird bei Sperre komplett vor Beruehrungen geschuetzt und um 95% abgedunkelt)
        AbsorbPointer(
          absorbing: widget.isLocked,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isLocked ? 0.05 : 1.0,
            child: widget.child,
          ),
        ),

        // 2. Sperr-Ebene & 95% abgedunkelter Schleier
        if (widget.isLocked)
          Positioned.fill(
            child: Listener(
              key: const Key('bed_lock_gesture_detector'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _startHolding(),
              onPointerUp: (_) => _cancelHolding(),
              onPointerCancel: (_) => _cancelHolding(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  // Wischgeste nach oben akkumulieren
                  _verticalDragDistance -= details.delta.dy;
                  if (_verticalDragDistance > 120.0) {
                    _triggerUnlock();
                  }
                },
                onVerticalDragEnd: (_) {
                  _verticalDragDistance = 0.0;
                },
                child: Container(
                  key: const Key('bed_lock_dimmed_scrim'),
                  color: AmoledColors.bedLockScrim,
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animierter Entsperr-Fortschrittsring
                            AnimatedBuilder(
                              animation: _unlockAnimationController,
                              builder: (context, _) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 88.0,
                                      height: 88.0,
                                      child: CircularProgressIndicator(
                                        value: _unlockAnimationController.value,
                                        strokeWidth: 4.0,
                                        backgroundColor:
                                            AmoledColors.surfaceElevated,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          AmoledColors.midnightBlue,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 38.0,
                                      color: AmoledColors.midnightBlue,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24.0),
                            const Text(
                              'Touch Lock',
                              style: TextStyle(
                                color: AmoledColors.textPrimary,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              '2s gedrueckt halten oder nach oben wischen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AmoledColors.textSecondary,
                                fontSize: 13.0,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
