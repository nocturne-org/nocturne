import 'package:flutter/material.dart';
import 'amoled_colors.dart';

/// Blendfreie Typografie fuer die naechtliche Audio-Wiedergabe.
/// Verwendet ausschliesslich gedimmte Off-White- und Slate-Toene.
abstract class AmoledTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AmoledColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AmoledColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AmoledColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    color: AmoledColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle headingMedium = headlineMedium;

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    color: AmoledColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: AmoledColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AmoledColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: AmoledColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AmoledColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AmoledColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AmoledColors.textTertiary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AmoledColors.textTertiary,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AmoledColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AmoledColors.textSecondary,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AmoledColors.textTertiary,
    height: 1.3,
  );

  /// Erstellt das blendfreie [TextTheme] fuer Nocturne.
  static TextTheme createTextTheme() {
    return const TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      displaySmall: displaySmall,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }
}
