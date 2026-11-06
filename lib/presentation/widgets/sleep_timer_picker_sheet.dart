import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/sleep_timer_state.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_theme.dart';
import '../theme/amoled_typography.dart';

/// Modal bottom sheet for configuring sleep timer presets and custom durations.
class SleepTimerPickerSheet extends StatelessWidget {
  final SleepTimerState currentState;
  final ValueChanged<Duration> onDurationSelected;
  final VoidCallback onCancelTimer;

  const SleepTimerPickerSheet({
    super.key,
    required this.currentState,
    required this.onDurationSelected,
    required this.onCancelTimer,
  });

  /// Displays the sleep timer picker bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required SleepTimerState currentState,
    required ValueChanged<Duration> onDurationSelected,
    required VoidCallback onCancelTimer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmoledColors.pureBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AmoledTheme.sheetRadius),
        ),
      ),
      builder: (ctx) => SleepTimerPickerSheet(
        currentState: currentState,
        onDurationSelected: onDurationSelected,
        onCancelTimer: onCancelTimer,
      ),
    );
  }

  void _showCustomMinutesDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AmoledColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AmoledColors.divider),
          ),
          title: Text(
            'Custom Sleep Timer',
            style: AmoledTypography.titleLarge.copyWith(
              color: AmoledColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter duration in minutes (1 - 720):',
                style: AmoledTypography.bodyMedium.copyWith(
                  color: AmoledColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AmoledTypography.titleLarge.copyWith(
                  color: AmoledColors.midnightBlue,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'e.g. 25',
                  hintStyle: AmoledTypography.bodyMedium.copyWith(
                    color: AmoledColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AmoledColors.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AmoledColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AmoledColors.midnightBlue),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AmoledColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AmoledColors.midnightBlue,
                foregroundColor: AmoledColors.pureBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final raw = controller.text.trim();
                final minutes = int.tryParse(raw);
                if (minutes != null && minutes > 0 && minutes <= 720) {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).pop();
                  onDurationSelected(Duration(minutes: minutes));
                }
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = [
      {'label': '5 min', 'duration': const Duration(minutes: 5)},
      {'label': '10 min', 'duration': const Duration(minutes: 10)},
      {'label': '15 min', 'duration': const Duration(minutes: 15)},
      {'label': '30 min', 'duration': const Duration(minutes: 30)},
      {'label': '45 min', 'duration': const Duration(minutes: 45)},
      {'label': '60 min', 'duration': const Duration(minutes: 60)},
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AmoledColors.disabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sleep Timer',
                  style: AmoledTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AmoledColors.textPrimary,
                  ),
                ),
                if (currentState.isActive || currentState.isGracePeriod)
                  TextButton.icon(
                    key: const Key('sleep_timer_turn_off_button'),
                    icon: const Icon(
                      Icons.timer_off_outlined,
                      size: 18,
                      color: AmoledColors.error,
                    ),
                    label: const Text(
                      'Turn Off',
                      style: TextStyle(color: AmoledColors.error),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancelTimer();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid of preset chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in presets)
                  _buildPresetChip(
                    context: context,
                    label: item['label'] as String,
                    duration: item['duration'] as Duration,
                  ),
                // Custom minutes button
                ActionChip(
                  key: const Key('sleep_timer_custom_chip'),
                  avatar: const Icon(
                    Icons.edit_calendar_outlined,
                    size: 18,
                    color: AmoledColors.violet,
                  ),
                  label: const Text('Custom...'),
                  labelStyle: const TextStyle(
                    color: AmoledColors.violet,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AmoledColors.surfaceCard,
                  side: const BorderSide(color: AmoledColors.violet),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: () => _showCustomMinutesDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required BuildContext context,
    required String label,
    required Duration duration,
  }) {
    final isCurrent = currentState.isActive &&
        (currentState.remainingDuration.inMinutes == duration.inMinutes ||
            currentState.totalDuration.inMinutes == duration.inMinutes);

    return ActionChip(
      key: Key('sleep_timer_preset_${duration.inMinutes}'),
      label: Text(label),
      labelStyle: TextStyle(
        color: isCurrent ? AmoledColors.pureBlack : AmoledColors.textPrimary,
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
      ),
      backgroundColor:
          isCurrent ? AmoledColors.midnightBlue : AmoledColors.surfaceCard,
      side: BorderSide(
        color: isCurrent ? AmoledColors.midnightBlue : AmoledColors.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onPressed: () {
        Navigator.of(context).pop();
        onDurationSelected(duration);
      },
    );
  }
}
