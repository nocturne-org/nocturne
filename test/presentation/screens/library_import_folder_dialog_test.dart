import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/presentation/screens/library_browser_screen.dart';
import 'package:nocturne/presentation/theme/amoled_theme.dart';

void main() {
  group('Library Folder Import Dialog Tests (TICK-V2-07)', () {
    testWidgets('Tapping import button opens folder import dialog',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AmoledTheme.themeData,
            home: const LibraryBrowserScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find import folder button
      final importBtn = find.byKey(const Key('library_import_folder_button'));
      expect(importBtn, findsOneWidget);

      // Tap import folder button
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.text('Import Audio Folder'), findsOneWidget);
      expect(find.byKey(const Key('import_folder_confirm_button')), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Import Audio Folder'), findsNothing);
    });
  });
}
