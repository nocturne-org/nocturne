import 'dart:io';

/// Pfad-Definitionen und Konstanten fuer die interne App-Sandbox von Nocturne.
/// Standard-Speicherort: /data/user/0/com.nocturne.audio/files/
abstract class SandboxPaths {
  /// Standard-Paketname der Android-App.
  static const String packageName = 'com.nocturne.audio';

  /// Standard-Sandbox-Pfad fuer Android.
  static const String defaultAndroidFilesDir =
      '/data/user/0/$packageName/files';

  /// Ordnername fuer heruntergeladene Hoerbuecher und Audio-Dateien.
  static const String audioDownloadsDir = 'audio_downloads';

  /// Ordnername fuer zwischengespeicherte Podcast-Episoden.
  static const String podcastCacheDir = 'podcast_cache';

  /// Ordnername fuer Cover-Bilder und Thumbnails.
  static const String coverCacheDir = 'cover_cache';

  /// Dateiendung fuer temporaere, unvollstaendige Download-Fragmente.
  static const String partFileExtension = '.part';

  /// Schutzdatei zur Vermeidung von Scans durch Drittanbieter-Apps
  /// und den Android MediaScanner.
  static const String noMediaFileName = '.nomedia';

  /// Schwellenwert fuer Speicherplatz-Warnungen (500 MB in Bytes).
  static const int minFreeSpaceWarningBytes = 500 * 1024 * 1024;

  /// Liefert den vollstaendigen Pfad fuer ein Unterverzeichnis der Sandbox.
  static String getSubdirectoryPath(String baseDir, String subDirName) {
    final separator = Platform.pathSeparator;
    if (baseDir.endsWith(separator)) {
      return '$baseDir$subDirName';
    }
    return '$baseDir$separator$subDirName';
  }

  /// Liefert den Pfad zum audio_downloads Verzeichnis.
  static String audioDownloadsPath(String baseDir) =>
      getSubdirectoryPath(baseDir, audioDownloadsDir);

  /// Liefert den Pfad zum podcast_cache Verzeichnis.
  static String podcastCachePath(String baseDir) =>
      getSubdirectoryPath(baseDir, podcastCacheDir);

  /// Liefert den Pfad zum cover_cache Verzeichnis.
  static String coverCachePath(String baseDir) =>
      getSubdirectoryPath(baseDir, coverCacheDir);
}
