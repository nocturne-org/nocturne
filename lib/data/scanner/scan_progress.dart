/// Fortschritts-Event fuer den rekursiven Bibliotheks-Scan.
class ScanProgress {
  const ScanProgress({
    required this.scannedFilesCount,
    required this.audioFilesFoundCount,
    required this.currentPath,
    this.isCompleted = false,
  });

  /// Gesamtanzahl der bisher geprueften Dateien und Ordner.
  final int scannedFilesCount;

  /// Anzahl bisher gefundener gueltiger Audio-Dateien.
  final int audioFilesFoundCount;

  /// Aktuell durchsuchter Ordner oder gepruefte Datei.
  final String currentPath;

  /// Status, ob der Scan vollstaendig abgeschlossen ist.
  final bool isCompleted;

  @override
  String toString() =>
      'ScanProgress(scanned: $scannedFilesCount, audio: $audioFilesFoundCount, completed: $isCompleted)';
}
