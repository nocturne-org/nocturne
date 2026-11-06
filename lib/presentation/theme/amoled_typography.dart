import 'package:flutter/material.dart';
import 'amoled_colors.dart';

/// Blendfreie Typografie fuer die naechtliche Audio-Wiedergabe.
/// Verwendet ausschliesslich gedimmte Off-White- und Slate-Toene.
abstract class AmoledTypography {
  /// Erstellt das blendfreie [TextTheme] fuer Nocturne.
  static TextTheme createTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AmoledColors.textPrimary,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AmoledColors.textPrimary,
        height: 1.25,
      ),
      displaySmall: TextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AmoledColors.textPrimary,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        color: AmoledColors.textPrimary,
        height: 1.35,
      ),
      headlineSmall: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        color: AmoledColors.textPrimary,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: AmoledColors.textPrimary,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: AmoledColors.textPrimary,
        height: 1.45,
      ),
      titleSmall: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: AmoledColors.textSecondary,
        height: 1.45,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        color: AmoledColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        color: AmoledColors.textSecondary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: AmoledColors.textTertiary,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AmoledColors.textPrimary,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AmoledColors.textSecondary,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AmoledColors.textTertiary,
        height: 1.3,
      ),
    );
  }
}
