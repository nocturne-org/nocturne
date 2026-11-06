import 'scanned_audio_file.dart';

/// Ergebnis eines inkrementellen Bibliotheks-Scans.
class ScanDiffResult {
  const ScanDiffResult({
    required this.addedFiles,
    required this.modifiedFiles,
    required this.deletedFilePaths,
    required this.unmodifiedFiles,
  });

  /// Neu gefundene Audio-Dateien.
  final List<ScannedAudioFile> addedFiles;

  /// Modifizierte Audio-Dateien (Groesse oder Aenderungsdatum weicht ab).
  final List<ScannedAudioFile> modifiedFiles;

  /// Zuvor bekannte Dateien, die auf dem Dateisystem nicht mehr existieren.
  final List<String> deletedFilePaths;

  /// Unveraenderte Audio-Dateien.
  final List<ScannedAudioFile> unmodifiedFiles;

  /// Gesamtzahl aller aktuell auf dem Speichermedium vorhandenen Audio-Dateien.
  int get totalCurrentFiles =>
      addedFiles.length + modifiedFiles.length + unmodifiedFiles.length;

  /// Ob Aenderungen (Neuzugaenge, Aenderungen oder Loeschungen) vorliegen.
  bool get hasChanges =>
      addedFiles.isNotEmpty ||
      modifiedFiles.isNotEmpty ||
      deletedFilePaths.isNotEmpty;

  @override
  String toString() =>
      'ScanDiffResult(added: ${addedFiles.length}, modified: ${modifiedFiles.length}, deleted: ${deletedFilePaths.length}, unchanged: ${unmodifiedFiles.length})';
}
