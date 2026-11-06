/// Hilfsklasse zur plattformuebergreifenden Sanitisierung von Datei- und Ordnernamen.
/// Bereinigt reservierte Zeichen (FAT32, exFAT, NTFS, ext4) und verhindert Pfad-Konflikte.
abstract class PathSanitizer {
  /// Illegale Zeichen in Dateisystemen (< > : " / \ | ? * sowie Steuerzeichen).
  static final RegExp _illegalChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Bereinigt einen Ordner- oder Dateinamen.
  static String sanitize(String input, {String fallback = 'Unbekannt'}) {
    var cleaned = input.replaceAll(_illegalChars, '-').trim();

    // Mehrfache Bindestriche und Leerzeichen normalisieren
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'-+'), '-');

    // Punkte und Leerzeichen am Ende entfernen (Windows/FAT-Konformitaet)
    while (cleaned.endsWith('.') || cleaned.endsWith(' ') || cleaned.endsWith('-')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    if (cleaned.isEmpty) {
      return fallback;
    }

    // Laengenbegrenzung pro Pfad-Komponente (maximal 120 Zeichen)
    if (cleaned.length > 120) {
      cleaned = cleaned.substring(0, 120).trim();
    }

    return cleaned;
  }
}
