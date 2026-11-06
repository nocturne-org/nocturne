/// Repraesentiert einen einzelnen geplanten Datei-Verschiebevorgang im Vorschau-Modus.
class OrganizePlanItem {
  const OrganizePlanItem({
    required this.sourcePath,
    required this.destinationPath,
    required this.author,
    required this.book,
    required this.title,
    this.trackNumber,
    this.isAlreadyOrganized = false,
    this.isDuplicate = false,
  });

  /// Urspruenglicher Dateipfad.
  final String sourcePath;

  /// Zielpfad im normierten Schema (/Audiobooks/Autor/Buch/01 - Titel.ext).
  final String destinationPath;

  /// Erkannter oder bereinigter Autor.
  final String author;

  /// Erkannter oder bereinigter Buchtitel.
  final String book;

  /// Erkannter oder bereinigter Track-Titel.
  final String title;

  /// Optionale Tracknummer.
  final int? trackNumber;

  /// Zeigt an, ob die Datei bereits am exakt richtigen Zielort liegt.
  final bool isAlreadyOrganized;

  /// Zeigt an, ob am Zielort bereits eine Datei existiert (Duplikat).
  final bool isDuplicate;

  @override
  String toString() =>
      'OrganizePlanItem(from: $sourcePath, to: $destinationPath, duplicate: $isDuplicate, organized: $isAlreadyOrganized)';
}
