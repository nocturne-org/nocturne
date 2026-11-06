import 'package:flutter/material.dart';

/// Farbpalette fuer das AMOLED Pure Black Bedtime Design System.
/// Entwickelt zur vollstaendigen Abschaltung von OLED-Pixeln (#000000)
/// und Vermeidung von Blendeffekten bei Dunkelheit.
///
/// Diese Datei ist die EINZIGE Quelle der Akzentfarben. Der Build-Validator
/// `tool/ui/check_palette.dart` schlaegt fehl, sobald ausserhalb dieser Datei
/// alte Akzente (Bernstein/Cyan) oder harte Hex-Werte fuer Blau/Violett
/// auftauchen.
abstract class AmoledColors {
  /// 100% Reines OLED-Schwarz zur Pixelabschaltung.
  static const Color pureBlack = Color(0xFF000000);

  /// Minimal erhoehte Hintergrundflaeche fuer Cards und Dialoge.
  static const Color surfaceElevated = Color(0xFF0D0E12);

  /// Flaechenfarbe fuer Bedtime-Karten und Listen.
  static const Color surfaceCard = Color(0xFF13151A);

  /// Gedaempfte Trennlinien und Raender.
  static const Color divider = Color(0xFF1E293B);

  // ---------------------------------------------------------------------------
  // Akzente: Nachtblau -> Indigo -> Violett
  // Kontrastverhaeltnisse gegen pureBlack:
  //   midnightBlue 4.68:1 (Normaltext zulaessig)
  //   indigo       4.24:1 (nur grosse/fette Schrift)
  //   violet       4.44:1 (nur grosse/fette Schrift)
  // Fuer gefuellte Buttons wird daher immer pureBlack als Vordergrund genutzt.
  // ---------------------------------------------------------------------------

  /// Primaerer Akzent: Mitternachtsblau (Navigation, Primaeraktionen, Progress).
  static const Color midnightBlue = Color(0xFF3B82F6);

  /// Sekundaerer Akzent: Indigo (Sekundaeraktionen, hervorgehobene Chips).
  static const Color indigo = Color(0xFF6366F1);

  /// Tertiaerer Akzent: Violett (Sleep-Timer, Nacht-Modus, Verlaeufe).
  static const Color violet = Color(0xFF8B5CF6);

  /// Sehr dunkles Nachtblau fuer grosse Flaechen und Hero-Hintergruende.
  /// Bleibt so dunkel, dass OLED-Pixel kaum leuchten.
  static const Color deepTwilight = Color(0xFF0B1224);

  /// Verlauf fuer Hero-Flaechen (Player-Header, Sheet-Kopf).
  /// Laeuft nach unten auf volles Schwarz aus, damit Pixel abgeschaltet werden.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x332B3A78),
      Color(0x1A101932),
      Color(0x00000000),
    ],
  );

  /// Aktiver Teil des Fortschrittsbalkens.
  static const Color progressActive = midnightBlue;

  /// Uebergaengsfarbton waehrend der Sleep-Timer-Ausblendung.
  static const Color progressFading = indigo;

  /// Farbton waehrend der Kulanzzeit nach Erreichen von Volume 0.
  static const Color progressGrace = violet;

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
  static const Color touchOverlay = Color(0x1A3B82F6);

  /// Maximale Abdunklung des Touch-Locks (95%).
  static const double bedLockDimFactor = 0.95;

  /// Sichtbare Abdunklungsschicht im Touch-Lock.
  static const Color bedLockScrim = Color(0xF2000509);
}
