import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bed_lock_provider.dart';
import '../providers/bedtime_audio_provider.dart';
import '../providers/sensor_providers.dart';
import '../providers/timer_providers.dart';
import '../theme/amoled_colors.dart';
import '../widgets/bed_lock_overlay.dart';
import '../widgets/bedtime_touch_target.dart';
import '../widgets/sleep_timer_circular_hud.dart';
import '../widgets/sleep_timer_picker_sheet.dart';
import '../widgets/seek_button.dart';

/// Haupt-Bedtime-Player-Screen fuer die Nacht gemaess Nocturne-Architektur (TICK-027 & TICK-028).
///
/// Merkmale:
/// - Kreisfoermiger Restzeit-Countdown-HUD mit Fortschrittsanzeige.
/// - One-Tap Schnellverlaengerung um 15 Minuten per grosser Taste.
/// - Anzeige des aktuellen Shake-Sensor-Profils (Nachttisch vs. Matratze) mit Schnellumschaltung.
/// - Grosse, kontraststarke Play/Pause- und 30s-Ruecksprung-Tasten fuer blinde Bedienung.
/// - Vollbild-Bed-Lock Touch-Sperre gegen versehentliche Bettdecken- und Kissenberuehrungen.
/// - Reiner AMOLED-Schwarz-Hintergrund (#000000) zur vollstaendigen Blendfreiheit.
class BedtimeScreen extends ConsumerWidget {
  const BedtimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerControllerProvider);
    final timerNotifier = ref.read(timerControllerProvider.notifier);
    final sensorProfile = ref.watch(sensorProfileProvider);
    final sensorNotifier = ref.read(sensorProfileProvider.notifier);
    final playerState = ref.watch(bedtimeAudioProvider);
    final playerNotifier = ref.read(bedtimeAudioProvider.notifier);
    final isLocked = ref.watch(bedLockProvider);
    final lockNotifier = ref.read(bedLockProvider.notifier);

    final title = playerState.title;
    final author = playerState.author;
    final isPlaying = playerState.isPlaying;

    return Scaffold(
      backgroundColor: AmoledColors.pureBlack,
      body: BedLockOverlay(
        key: const Key('bed_lock_overlay'),
        isLocked: isLocked,
        onUnlock: () => lockNotifier.unlock(),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                // 1. Kopfleiste mit Shake-Sensor-Profil-Badge und Bed-Lock-Taste
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sensorprofil-Anzeige & Schnellwechsler
                    InkWell(
                      key: const Key('sensor_profile_toggle'),
                      onTap: () => sensorNotifier.toggleProfile(),
                      borderRadius: BorderRadius.circular(20.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: AmoledColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: AmoledColors.divider,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.vibration,
                              size: 16.0,
                              color: AmoledColors.midnightBlue,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              sensorProfile.displayName,
                              style: const TextStyle(
                                color: AmoledColors.textPrimary,
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dedicated Sleep Timer Button
                        IconButton(
                          key: const Key('sleep_timer_menu_button'),
                          icon: Icon(
                            timerState.isActive
                                ? Icons.timer_rounded
                                : Icons.timer_outlined,
                            color: timerState.isActive
                                ? AmoledColors.violet
                                : AmoledColors.textSecondary,
                            size: 22.0,
                          ),
                          tooltip: 'Sleep Timer',
                          onPressed: () {
                            SleepTimerPickerSheet.show(
                              context: context,
                              currentState: timerState,
                              onDurationSelected: (d) =>
                                  timerNotifier.startTimer(d),
                              onCancelTimer: () => timerNotifier.cancelTimer(),
                            );
                          },
                        ),

                        // Touch Lock Aktivierungstaste (TICK-028 & TICK-V2-02)
                        IconButton(
                          key: const Key('bed_lock_activate_button'),
                          icon: const Icon(
                            Icons.lock_outline,
                            color: AmoledColors.midnightBlue,
                            size: 22.0,
                          ),
                          tooltip: 'Touch Lock',
                          onPressed: () => lockNotifier.lock(),
                        ),

                        // Optionaler Timer-Abbrechen Button wenn aktiv
                        if (timerState.isActive || timerState.isGracePeriod)
                          IconButton(
                            key: const Key('timer_cancel_button'),
                            icon: const Icon(
                              Icons.timer_off_outlined,
                              color: AmoledColors.textSecondary,
                              size: 22.0,
                            ),
                            tooltip: 'Timer abbrechen',
                            onPressed: () => timerNotifier.cancelTimer(),
                          ),
                      ],
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // 2. Medien-Titel und Autor (grosse, ruhige Typografie)
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AmoledColors.textPrimary,
                    fontSize: 22.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  author,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AmoledColors.textSecondary,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 1),

                // 3. Grosser kreisfoermiger Countdown-HUD
                SleepTimerCircularHud(
                  key: const Key('sleep_timer_circular_hud'),
                  timerState: timerState,
                  onTap: () {
                    SleepTimerPickerSheet.show(
                      context: context,
                      currentState: timerState,
                      onDurationSelected: (d) => timerNotifier.startTimer(d),
                      onCancelTimer: () => timerNotifier.cancelTimer(),
                    );
                  },
                ),

                const SizedBox(height: 24.0),

                // 4. One-Tap Schnellverlaengerung um 15 Minuten
                BedtimeActionButton(
                  key: const Key('add_15_minutes_button'),
                  label: '+15 Min',
                  icon: Icons.more_time,
                  isAccent: true,
                  onPressed: () => timerNotifier.add15Minutes(),
                ),

                const Spacer(flex: 2),

                // 5. Grosse Transport-Bedientasten fuer blinde Nacht-Bedienung
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 15s Rueckwaerts-Taste mit Hold-Seek
                    SeekButton(
                      key: const Key('rewind_15_button'),
                      isForward: false,
                      tooltip: '15 Sekunden zurueck (Halten zum Schnellspulen)',
                      onSingleSeek: () => playerNotifier.rewind15(),
                      onContinuousTick: () =>
                          playerNotifier.seekRelative(const Duration(seconds: -5)),
                    ),

                    // Grosse zentrale Play / Pause Taste
                    BedtimeTouchTarget(
                      key: const Key('play_pause_button'),
                      minWidth: 92.0,
                      minHeight: 92.0,
                      borderRadius: 46.0,
                      tooltip: isPlaying ? 'Pausieren' : 'Abspielen',
                      onTap: () => playerNotifier.togglePlayPause(),
                      child: Container(
                        width: 84.0,
                        height: 84.0,
                        decoration: const BoxDecoration(
                          color: AmoledColors.midnightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 48.0,
                          color: AmoledColors.pureBlack,
                        ),
                      ),
                    ),

                    // 15s Vorwaerts-Taste mit Hold-Seek
                    SeekButton(
                      key: const Key('forward_15_button'),
                      isForward: true,
                      tooltip: '15 Sekunden vorwaerts (Halten zum Schnellspulen)',
                      onSingleSeek: () => playerNotifier.forward15(),
                      onContinuousTick: () =>
                          playerNotifier.seekRelative(const Duration(seconds: 5)),
                    ),
                  ],
                ),

                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
