import '../models/storage/saf_directory.dart';

/// Abstraktes Repository fuer Verzeichnis- und Speicher-Operationen.
/// Kapselt den Zugriff auf das Android Storage Access Framework (SAF).
abstract class StorageRepository {
  /// Oeffnet den System-Ordner-Picker (ACTION_OPEN_DOCUMENT_TREE).
  /// Fordert und persistiert bei Auswahl automatisch `takePersistableUriPermission`.
  /// Gibt `null` zurueck, falls der Benutzer den Dialog abgebrochen hat.
  Future<SafDirectory?> pickDirectory();

  /// Liefert alle dauerhaft registrierten und berechtigten SAF-Ordner.
  Future<List<SafDirectory>> getPersistedDirectories();

  /// Gibt die persistierte Berechtigung fuer einen URI vollstaendig frei
  /// und entfernt ihn aus der Liste der verwalteten Bibliotheks-Pfade.
  Future<bool> releasePersistedDirectory(String treeUri);

  /// Prueft fehlertolerant, ob der Ordner weiterhin erreichbar und gueltig ist.
  /// Erkennt entfernte SD-Karten, geloeschte Pfade und widerrufene Rechte.
  Future<SafDirectoryStatus> verifyDirectoryAccess(String treeUri);

  /// Liest rekursiv oder flach alle Audio-Dateien im SAF-Ordner ein.
  /// [extensions] definiert die zu filternden Endungen (Standard: mp3, m4b, m4a, flac, opus).
  Future<List<SafFileItem>> listAudioFiles(
    String treeUri, {
    List<String> extensions = const ['mp3', 'm4b', 'm4a', 'flac', 'opus'],
  });
}
