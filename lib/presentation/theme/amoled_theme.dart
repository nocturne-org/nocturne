import 'package:flutter/material.dart';
import 'amoled_colors.dart';
import 'amoled_typography.dart';

/// Zentrales Bedtime Design-System fuer Nocturne.
/// Bietet ein 100% reines AMOLED-Schwarz-Theme (#000000) mit blendfreier Typografie
/// und barrierefreien Touch-Zielen (>= 48 dp).
abstract class AmoledTheme {
  /// Mindestabmessung fuer interaktive Touch-Ziele im Bedtime-Modus in dp.
  static const double minTouchTargetSize = 48.0;

  /// Erzeugt das vollstaendige AMOLED Pure Black [ThemeData].
  static ThemeData get themeData {
    final textTheme = AmoledTypography.createTextTheme();

    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AmoledColors.amberAccent,
      onPrimary: AmoledColors.pureBlack,
      secondary: AmoledColors.cyanAccent,
      onSecondary: AmoledColors.pureBlack,
      error: AmoledColors.error,
      onError: AmoledColors.pureBlack,
      surface: AmoledColors.pureBlack,
      onSurface: AmoledColors.textPrimary,
      outline: AmoledColors.divider,
      shadow: AmoledColors.pureBlack,
      scrim: AmoledColors.pureBlack,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AmoledColors.pureBlack,
      canvasColor: AmoledColors.pureBlack,
      cardColor: AmoledColors.surfaceElevated,
      dividerColor: AmoledColors.divider,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // AppBar Konfiguration (100% Schwarz, keine Schatten)
      appBarTheme: const AppBarTheme(
        backgroundColor: AmoledColors.pureBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AmoledColors.textPrimary,
          size: 24.0,
        ),
        actionsIconTheme: IconThemeData(
          color: AmoledColors.textPrimary,
          size: 24.0,
        ),
        titleTextStyle: TextStyle(
          color: AmoledColors.textPrimary,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Konfiguration
      cardTheme: const CardThemeData(
        color: AmoledColors.surfaceCard,
        elevation: 0.0,
        margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
          side: BorderSide(color: AmoledColors.divider, width: 1.0),
        ),
      ),

      // Dialog Konfiguration
      dialogTheme: const DialogThemeData(
        backgroundColor: AmoledColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20.0)),
          side: BorderSide(color: AmoledColors.divider, width: 1.0),
        ),
        titleTextStyle: TextStyle(
          color: AmoledColors.textPrimary,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: AmoledColors.textSecondary,
          fontSize: 14.0,
        ),
      ),

      // BottomSheet Konfiguration
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AmoledColors.pureBlack,
        modalBackgroundColor: AmoledColors.pureBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          side: BorderSide(color: AmoledColors.divider, width: 1.0),
        ),
      ),

      // Slider Konfiguration (fuer Sleep-Timer & Lautstaerke)
      sliderTheme: SliderThemeData(
        activeTrackColor: AmoledColors.amberAccent,
        inactiveTrackColor: AmoledColors.divider,
        thumbColor: AmoledColors.amberAccent,
        overlayColor: AmoledColors.amberAccent.withAlpha(32),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
      ),

      // Button Themes mit erzwungener Mindestgroesse >= 48 dp
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AmoledColors.amberAccent,
          foregroundColor: AmoledColors.pureBlack,
          elevation: 0.0,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: const TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AmoledColors.textPrimary,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          side: const BorderSide(color: AmoledColors.divider, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AmoledColors.cyanAccent,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          foregroundColor: AmoledColors.textPrimary,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AmoledColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AmoledColors.amberAccent;
          }
          return AmoledColors.disabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AmoledColors.amberAccent.withAlpha(64);
          }
          return AmoledColors.surfaceElevated;
        }),
      ),
    );
  }
}
