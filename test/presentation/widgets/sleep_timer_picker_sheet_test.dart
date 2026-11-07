import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/presentation/state/sleep_timer_state.dart';
import 'package:nocturne/presentation/widgets/sleep_timer_picker_sheet.dart';

void main() {
  group('SleepTimerPickerSheet Widget Tests (TICK-V2-02)', () {
    Widget buildSheet({
      required SleepTimerState currentState,
      ValueChanged<Duration>? onDurationSelected,
      VoidCallback? onCancelTimer,
      VoidCallback? onChapterEndSelected,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SleepTimerPickerSheet(
            currentState: currentState,
            onDurationSelected: onDurationSelected ?? (_) {},
            onCancelTimer: onCancelTimer ?? () {},
            onChapterEndSelected: onChapterEndSelected,
          ),
        ),
      );
    }

    testWidgets('Renders all preset chips, chapter end, and custom chip',
        (tester) async {
      await tester.pumpWidget(
        buildSheet(currentState: SleepTimerState.initial),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_5')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_10')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_15')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_30')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_45')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_60')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_chapter_end_chip')),
          findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_custom_chip')), findsOneWidget);

      // Turn Off button should not be visible when timer is inactive
      expect(find.byKey(const Key('sleep_timer_turn_off_button')),
          findsNothing);
    });

    testWidgets('Tapping a preset chip invokes onDurationSelected',
        (tester) async {
      Duration? selectedDuration;

      await tester.pumpWidget(
        buildSheet(
          currentState: SleepTimerState.initial,
          onDurationSelected: (d) => selectedDuration = d,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep_timer_preset_15')));
      await tester.pumpAndSettle();

      expect(selectedDuration, const Duration(minutes: 15));
    });

    testWidgets('Tapping chapter end invokes onChapterEndSelected or fallback',
        (tester) async {
      bool chapterEndInvoked = false;

      await tester.pumpWidget(
        buildSheet(
          currentState: SleepTimerState.initial,
          onChapterEndSelected: () => chapterEndInvoked = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep_timer_chapter_end_chip')));
      await tester.pumpAndSettle();

      expect(chapterEndInvoked, true);
    });

    testWidgets('Active timer displays Turn Off button and invokes onCancelTimer',
        (tester) async {
      bool cancelInvoked = false;

      const activeState = SleepTimerState(
        status: SleepTimerStatus.counting,
        totalDuration: Duration(minutes: 30),
        remainingDuration: Duration(minutes: 20),
        volumeFactor: 1.0,
        preset: SleepTimerPreset.m30,
      );

      await tester.pumpWidget(
        buildSheet(
          currentState: activeState,
          onCancelTimer: () => cancelInvoked = true,
        ),
      );
      await tester.pumpAndSettle();

      final turnOffFinder =
          find.byKey(const Key('sleep_timer_turn_off_button'));
      expect(turnOffFinder, findsOneWidget);

      await tester.tap(turnOffFinder);
      await tester.pumpAndSettle();

      expect(cancelInvoked, true);
    });

    testWidgets('Touch target height for chips is at least 48dp',
        (tester) async {
      await tester.pumpWidget(
        buildSheet(currentState: SleepTimerState.initial),
      );
      await tester.pumpAndSettle();

      final chipKeys = [
        'sleep_timer_preset_5',
        'sleep_timer_preset_10',
        'sleep_timer_preset_15',
        'sleep_timer_preset_30',
        'sleep_timer_preset_45',
        'sleep_timer_preset_60',
        'sleep_timer_chapter_end_chip',
        'sleep_timer_custom_chip',
      ];

      for (final key in chipKeys) {
        final chipSize = tester.getSize(find.byKey(Key(key)));
        expect(
          chipSize.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Chip $key must satisfy the 48dp minimum touch target height',
        );
      }
    });
  });
}
