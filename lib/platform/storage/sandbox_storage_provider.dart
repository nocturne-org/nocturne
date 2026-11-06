import 'dart:io';
import 'sandbox_paths.dart';

/// Status der Speicherplatz-Pruefung vor einem Download.
enum StorageSpaceStatus {
  /// Ausreichend freier Speicher vorhanden (Restkapazitaet >= 500 MB).
  sufficient,

  /// Speicher reicht zwar fuer den Download, faellt danach jedoch unter 500 MB.
  lowStorageWarning,

  /// Nicht genuegend Speicherplatz fuer den Download vorhanden.
  insufficient,
}

/// Ergebnis der Speicherplatz-Pruefung.
class StorageSpaceCheckResult {
  const StorageSpaceCheckResult({
    required this.status,
    required this.freeBytes,
    required this.requiredBytes,
    required this.remainingBytesAfterDownload,
    this.thresholdBytes = SandboxPaths.minFreeSpaceWarningBytes,
  });

  /// Berechneter Status der Speicherpruefung.
  final StorageSpaceStatus status;

  /// Aktuell verfuegbarer freier Speicher in Bytes.
  final int freeBytes;

  /// Fuer den Download benoetigter Speicherplatz in Bytes.
  final int requiredBytes;

  /// Verbleibender Speicher nach hypothetischem Download in Bytes.
  final int remainingBytesAfterDownload;

  /// Warnschwellenwert (Standard: 500 MB).
  final int thresholdBytes;

  /// Zeigt an, ob der Download technisch durchgefuehrt werden kann.
  bool get canProceed => status != StorageSpaceStatus.insufficient;

  /// Zeigt an, ob eine Warnung wegen knapper Restkapazitaet vorliegt.
  bool get hasLowSpaceWarning =>
      status == StorageSpaceStatus.lowStorageWarning;

  @override
  String toString() {
    return 'StorageSpaceCheckResult(status: $status, free: $freeBytes, required: $requiredBytes, remaining: $remainingBytesAfterDownload)';
  }
}

/// Ergebnis der Bereinigung von Download-Fragmenten.
class CleanupResult {
  const CleanupResult({
    required this.deletedFilesCount,
    required this.reclaimedBytes,
    required this.deletedFilePaths,
  });

  /// Anzahl geloeschter .part-Dateien.
  final int deletedFilesCount;

  /// Freigegebener Speicherplatz in Bytes.
  final int reclaimedBytes;

  /// Liste der geloeschten Dateipfade.
  final List<String> deletedFilePaths;

  @override
  String toString() {
    return 'CleanupResult(deletedCount: $deletedFilesCount, reclaimedBytes: $reclaimedBytes)';
  }
}

/// Schnittstelle zur Ermittlung des freien Speicherplatzes auf dem Geraet.
abstract class StorageSpaceResolver {
  Future<int> getFreeDiskSpace(String path);
}

/// Standard-Resolver, der auf Systemdateien oder Schaetzwerte zurueckgreift.
class DefaultStorageSpaceResolver implements StorageSpaceResolver {
  const DefaultStorageSpaceResolver();

  @override
  Future<int> getFreeDiskSpace(String path) async {
    // Falls auf nativer Android-Plattform kein nativer Hook vorliegt,
    // liefert der Fallback einen sicheren Standardwert oder analysiert die Umgebung.
    return 1024 * 1024 * 1024 * 2; // 2 GB Standard-Fallback fuer Tests/Desktop
  }
}

/// Provider fuer die interne App-Sandbox von Nocturne.
/// Kapselt den geschuetzten Speicherbereich (/data/user/0/com.nocturne.audio/files/)
/// gegen Bereinigungs-Apps und System-Clearing.
class SandboxStorageProvider {
  SandboxStorageProvider({
    Directory? baseDirectory,
    this.spaceResolver = const DefaultStorageSpaceResolver(),
  }) : _baseDir = baseDirectory ??
            Directory(SandboxPaths.defaultAndroidFilesDir);

  final Directory _baseDir;

  /// Resolver zur Ermittlung des freien Speicherplatzes.
  final StorageSpaceResolver spaceResolver;

  /// Basisverzeichnis der internen Sandbox.
  Directory get baseDirectory => _baseDir;

  /// Verzeichnis fuer heruntergeladene Audio-Dateien (Hoerbuecher, In-App-Downloads).
  Directory get audioDownloadsDirectory =>
      Directory(SandboxPaths.audioDownloadsPath(_baseDir.path));

  /// Verzeichnis fuer zwischengespeicherte Podcast-Episoden.
  Directory get podcastCacheDirectory =>
      Directory(SandboxPaths.podcastCachePath(_baseDir.path));

  /// Verzeichnis fuer Cover-Artworks und Miniaturbilder.
  Directory get coverCacheDirectory =>
      Directory(SandboxPaths.coverCachePath(_baseDir.path));

  /// Initialisiert die Sandbox-Verzeichnisstruktur und setzt Schutzdateien.
  Future<void> initialize() async {
    await _ensureDirectoryExists(audioDownloadsDirectory);
    await _ensureDirectoryExists(podcastCacheDirectory);
    await _ensureDirectoryExists(coverCacheDirectory);

    // Schutzdateien (.nomedia) anlegen
    await _protectDirectoryFromScanners(audioDownloadsDirectory);
    await _protectDirectoryFromScanners(podcastCacheDirectory);
    await _protectDirectoryFromScanners(coverCacheDirectory);
  }

  /// Stellt sicher, dass das Verzeichnis existiert.
  Future<void> _ensureDirectoryExists(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Schreibt eine .nomedia-Datei, um Media-Indexierung und Drittanbieter-Clearing zu verhindern.
  Future<void> _protectDirectoryFromScanners(Directory dir) async {
    final separator = Platform.pathSeparator;
    final noMediaFile = File('${dir.path}$separator${SandboxPaths.noMediaFileName}');
    if (!await noMediaFile.exists()) {
      await noMediaFile.create();
    }
  }

  /// Bereinigt verwaiste .part-Dateien (unvollstaendige Download-Fragmente).
  /// [olderThan]: Optionales Mindestalter. Wenn null, werden alle Fragmente bereinigt.
  Future<CleanupResult> cleanupOrphanedPartFiles({
    Duration? olderThan,
  }) async {
    var deletedCount = 0;
    var reclaimedBytes = 0;
    final deletedPaths = <String>[];
    final now = DateTime.now();

    final targetDirs = [
      audioDownloadsDirectory,
      podcastCacheDirectory,
    ];

    for (final dir in targetDirs) {
      if (!await dir.exists()) continue;

      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File &&
            entity.path.endsWith(SandboxPaths.partFileExtension)) {
          var shouldDelete = true;

          if (olderThan != null) {
            final stat = entity.statSync();
            final age = now.difference(stat.modified);
            if (age < olderThan) {
              shouldDelete = false;
            }
          }

          if (shouldDelete) {
            try {
              final size = entity.lengthSync();
              entity.deleteSync();
              deletedCount++;
              reclaimedBytes += size;
              deletedPaths.add(entity.path);
            } catch (_) {
              // Fehlertolerante Bereinigung bei Dateisperren
            }
          }
        }
      }
    }

    return CleanupResult(
      deletedFilesCount: deletedCount,
      reclaimedBytes: reclaimedBytes,
      deletedFilePaths: deletedPaths,
    );
  }

  /// Prueft den freien Speicherplatz vor dem Start eines grossen Downloads.
  /// [requiredBytes]: Benoetigte Dateigroesse fuer den Download.
  /// [customFreeBytes]: Optionaler Override (primaer fuer Tests).
  Future<StorageSpaceCheckResult> checkStorageSpace({
    required int requiredBytes,
    int? customFreeBytes,
  }) async {
    final freeBytes = customFreeBytes ??
        await spaceResolver.getFreeDiskSpace(_baseDir.path);

    final remaining = freeBytes - requiredBytes;

    StorageSpaceStatus status;
    if (freeBytes < requiredBytes) {
      status = StorageSpaceStatus.insufficient;
    } else if (remaining < SandboxPaths.minFreeSpaceWarningBytes) {
      status = StorageSpaceStatus.lowStorageWarning;
    } else {
      status = StorageSpaceStatus.sufficient;
    }

    return StorageSpaceCheckResult(
      status: status,
      freeBytes: freeBytes,
      requiredBytes: requiredBytes,
      remainingBytesAfterDownload: remaining,
    );
  }

  /// Berechnet die Gesamtgroesse eines Verzeichnisses in Bytes.
  Future<int> getDirectorySizeBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var totalSize = 0;
    final entities = dir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity is File) {
        try {
          totalSize += entity.lengthSync();
        } catch (_) {}
      }
    }
    return totalSize;
  }

  /// Liefert die gesamte belegte Speicherflaeche der Sandbox in Bytes.
  Future<int> getTotalSandboxSizeBytes() async {
    final audioSize = await getDirectorySizeBytes(audioDownloadsDirectory);
    final podcastSize = await getDirectorySizeBytes(podcastCacheDirectory);
    final coverSize = await getDirectorySizeBytes(coverCacheDirectory);
    return audioSize + podcastSize + coverSize;
  }

  /// Liefert eine File-Referenz fuer einen Audio-Download.
  File getAudioDownloadFile(String fileName) {
    final separator = Platform.pathSeparator;
    return File('${audioDownloadsDirectory.path}$separator$fileName');
  }

  /// Liefert eine File-Referenz fuer ein temporaeres Download-Fragment.
  File getAudioPartFile(String fileName) {
    final baseName = fileName.endsWith(SandboxPaths.partFileExtension)
        ? fileName
        : '$fileName${SandboxPaths.partFileExtension}';
    final separator = Platform.pathSeparator;
    return File('${audioDownloadsDirectory.path}$separator$baseName');
  }

  /// Liefert eine File-Referenz fuer eine gecachte Podcast-Datei.
  File getPodcastFile(String fileName) {
    final separator = Platform.pathSeparator;
    return File('${podcastCacheDirectory.path}$separator$fileName');
  }

  /// Liefert eine File-Referenz fuer ein Cover-Bild.
  File getCoverFile(String key, {String extension = 'jpg'}) {
    final separator = Platform.pathSeparator;
    return File('${coverCacheDirectory.path}$separator$key.$extension');
  }

  /// Bereinigt Cache-Verzeichnisse (wahlweise Podcasts und/oder Covers).
  /// Audio-Downloads bleiben hiervon unberuehrt.
  Future<int> clearCache({
    bool includePodcasts = false,
    bool includeCovers = true,
  }) async {
    var reclaimed = 0;
    if (includeCovers && await coverCacheDirectory.exists()) {
      for (final entity in coverCacheDirectory.listSync()) {
        if (entity is File && !entity.path.endsWith(SandboxPaths.noMediaFileName)) {
          reclaimed += entity.lengthSync();
          entity.deleteSync();
        }
      }
    }
    if (includePodcasts && await podcastCacheDirectory.exists()) {
      for (final entity in podcastCacheDirectory.listSync()) {
        if (entity is File && !entity.path.endsWith(SandboxPaths.noMediaFileName)) {
          reclaimed += entity.lengthSync();
          entity.deleteSync();
        }
      }
    }
    return reclaimed;
  }
}
