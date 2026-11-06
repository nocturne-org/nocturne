import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/presentation/theme/amoled_colors.dart';
import 'package:nocturne/presentation/theme/amoled_theme.dart';
import 'package:nocturne/presentation/theme/amoled_typography.dart';
import 'package:nocturne/presentation/widgets/bedtime_touch_target.dart';

void main() {
  group('AMOLED Pure Black Theme Tests (TICK-026)', () {
    test('Hintergruende sind zu 100% #000000 fuer OLED-Pixelabschaltung', () {
      expect(AmoledColors.pureBlack.toARGB32(), 0xFF000000);

      final theme = AmoledTheme.themeData;
      expect(theme.scaffoldBackgroundColor.toARGB32(), 0xFF000000);
      expect(theme.canvasColor.toARGB32(), 0xFF000000);
      expect(theme.colorScheme.surface.toARGB32(), 0xFF000000);
      expect(theme.appBarTheme.backgroundColor?.toARGB32(), 0xFF000000);
      expect(theme.bottomSheetTheme.backgroundColor?.toARGB32(), 0xFF000000);
    });

    test('Gedaempfte Akzentfarben (Bernstein #F59E0B und Nacht-Cyan #06B6D4)',
        () {
      expect(AmoledColors.amberAccent.toARGB32(), 0xFFF59E0B);
      expect(AmoledColors.cyanAccent.toARGB32(), 0xFF06B6D4);

      final theme = AmoledTheme.themeData;
      expect(theme.colorScheme.primary.toARGB32(), 0xFFF59E0B);
      expect(theme.colorScheme.secondary.toARGB32(), 0xFF06B6D4);
    });

    test('Typografie verwendet blendfreie Off-White-Toene statt grelles Weiss',
        () {
      expect(AmoledColors.textPrimary.toARGB32(), 0xFFE2E8F0);
      expect(AmoledColors.textSecondary.toARGB32(), 0xFF94A3B8);

      final textTheme = AmoledTypography.createTextTheme();

      // Pruefen, dass kein Text-Stil das grelle Standard-Weiss (#FFFFFF) verwendet
      final styles = [
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
      ];

      for (final s in styles) {
        expect(s?.color?.toARGB32(), isNot(0xFFFFFFFF));
      }
    });

    test('Touch-Ziele in ThemeData garantieren mindestens 48x48 dp', () {
      expect(AmoledTheme.minTouchTargetSize, 48.0);

      final theme = AmoledTheme.themeData;
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);

      final elevatedMin =
          theme.elevatedButtonTheme.style?.minimumSize?.resolve({});
      expect(elevatedMin?.width, greaterThanOrEqualTo(48.0));
      expect(elevatedMin?.height, greaterThanOrEqualTo(48.0));

      final outlinedMin =
          theme.outlinedButtonTheme.style?.minimumSize?.resolve({});
      expect(outlinedMin?.width, greaterThanOrEqualTo(48.0));
      expect(outlinedMin?.height, greaterThanOrEqualTo(48.0));

      final iconBtnMin = theme.iconButtonTheme.style?.minimumSize?.resolve({});
      expect(iconBtnMin?.width, greaterThanOrEqualTo(48.0));
      expect(iconBtnMin?.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('BedtimeTouchTarget erzwingt mindestens 48x48 dp Abmessung',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AmoledTheme.themeData,
          home: Scaffold(
            body: Center(
              child: BedtimeTouchTarget(
                onTap: () {},
                child: const SizedBox(width: 20, height: 20),
              ),
            ),
          ),
        ),
      );

      final targetFinder = find.byType(BedtimeTouchTarget);
      expect(targetFinder, findsOneWidget);

      final size = tester.getSize(targetFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
        'BedtimeIconButton bietet barrierefreie 48x48 dp Mindestgroesse',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AmoledTheme.themeData,
          home: Scaffold(
            body: Center(
              child: BedtimeIconButton(
                icon: Icons.play_arrow,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(BedtimeIconButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });
  });
}
