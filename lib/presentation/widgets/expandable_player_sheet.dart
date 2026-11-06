import 'package:flutter/material.dart';
import '../screens/bedtime_screen.dart';
import '../theme/amoled_colors.dart';
import '../theme/amoled_theme.dart';

/// Full-screen expandable Bedtime Player sheet that can be collapsed with a swipe down.
class ExpandablePlayerSheet extends StatelessWidget {
  const ExpandablePlayerSheet({super.key});

  /// Displays the bedtime player sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AmoledColors.pureBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AmoledTheme.sheetRadius),
        ),
      ),
      builder: (ctx) => const ExpandablePlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AmoledColors.pureBlack,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 12.0) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          color: AmoledColors.pureBlack,
          child: Column(
            children: [
              // Swipe down drag handle & collapse bar
              Container(
                padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                child: Center(
                  child: Container(
                    key: const Key('player_sheet_drag_handle'),
                    width: 48.0,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AmoledColors.disabled,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
              // Header collapse button
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    key: const Key('player_sheet_collapse_button'),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 32.0,
                      color: AmoledColors.textSecondary,
                    ),
                    tooltip: 'Collapse Player',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              // Embedded bedtime player
              const Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: 600.0,
                    child: BedtimeScreen(),
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
