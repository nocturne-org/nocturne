import 'package:flutter/material.dart';
import '../../platform/updater/app_update_info.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_typography.dart';

/// Minimalistischer AMOLED-Dialog zur Anzeige eines verfuegbaren App-Updates.
class UpdateNotificationDialog extends StatelessWidget {
  const UpdateNotificationDialog({
    super.key,
    required this.updateInfo,
    required this.onInstallPressed,
    this.onDismiss,
  });

  final AppUpdateInfo updateInfo;
  final VoidCallback onInstallPressed;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (updateInfo.apkSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return AlertDialog(
      backgroundColor: AmoledColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AmoledColors.divider),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.system_update_rounded,
            color: AmoledColors.amberAccent,
            size: 26,
          ),
          const SizedBox(width: 12),
          Text(
            'Update verfügbar',
            style: AmoledTypography.headingMedium,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Version: ${updateInfo.tagName}',
                style: AmoledTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AmoledColors.amberAccent,
                ),
              ),
              const Spacer(),
              Text(
                '$sizeMb MB',
                style: AmoledTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (updateInfo.releaseNotes.isNotEmpty) ...[
            Text(
              'Änderungen:',
              style: AmoledTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  updateInfo.releaseNotes,
                  style: AmoledTypography.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: Text(
            'Später',
            style: AmoledTypography.bodyMedium.copyWith(
              color: AmoledColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AmoledColors.amberAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onInstallPressed();
          },
          child: const Text(
            'Jetzt aktualisieren',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
