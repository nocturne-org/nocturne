import 'package:flutter/material.dart';

/// Farbpalette fuer das AMOLED Pure Black Bedtime Design System.
/// Entwickelt zur vollstaendigen Abschaltung von OLED-Pixeln (#000000)
/// und Vermeidung von Blendeffekten bei Dunkelheit.
abstract class AmoledColors {
  /// 100% Reines OLED-Schwarz zur Pixelabschaltung.
  static const Color pureBlack = Color(0xFF000000);

  /// Minimal erhoehte Hintergrundflaeche fuer Cards und Dialoge.
  static const Color surfaceElevated = Color(0xFF0D0E12);

  /// Flaechenfarbe fuer Bedtime-Karten und Listen.
  static const Color surfaceCard = Color(0xFF13151A);

  /// Gedaempfte Trennlinien und Raender.
  static const Color divider = Color(0xFF1E293B);

  /// Primaerer Bedtime-Akzent: Sanftes Bernstein (warm, schlaffoerdernd).
  static const Color amberAccent = Color(0xFFF59E0B);

  /// Sekundaerer Bedtime-Akzent: Nacht-Cyan (kuehl, unaufdringlich).
  static const Color cyanAccent = Color(0xFF06B6D4);

  /// Primaerer Text: Gedimmtes Off-White (kein grelles #FFFFFF).
  static const Color textPrimary = Color(0xFFE2E8F0);

  /// Sekundaerer Text: Gedaempftes Slate fuer Untertitel und Metadaten.
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Tertiaerer Text fuer Zeitstempel und inaktive Labels.
  static const Color textTertiary = Color(0xFF64748B);

  /// Deaktivierte Elemente und inaktive Icons.
  static const Color disabled = Color(0xFF334155);

  /// Gedaempftes Nacht-Rot fuer Fehleranzeigen.
  static const Color error = Color(0xFFEF4444);

  /// Gedaempftes Gruen fuer Statusmeldungen und Bestaetigungen.
  static const Color success = Color(0xFF10B981);

  /// Sanfte Overlay-Farbe fuer Touch-Gesten (Alpha-gedimmt).
  static const Color touchOverlay = Color(0x1AF59E0B);
}
