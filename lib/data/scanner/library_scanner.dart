import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'audio_format.dart';
import 'scan_diff_result.dart';
import 'scan_progress.dart';
import 'scanned_audio_file.dart';

/// Top-Level-Funktion fuer die Isolate-Traversierung.
/// Scannt ein Verzeichnis vollstaendig ohne Blockierung des UI-Threads.
List<Map<String, dynamic>> _traverseDirectoryInIsolate(String rootPath) {
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return [];

  final found = <Map<String, dynamic>>[];
  final entities = dir.listSync(recursive: true, followLinks: false);

  for (final entity in entities) {
    if (entity is File) {
      final format = AudioFormat.fromPath(entity.path);
      if (format != null) {
        try {
          final stat = entity.statSync();
          final fileName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path;

          found.add({
            'path': entity.path,
            'name': fileName,
            'format': format.name,
            'sizeBytes': stat.size,
            'lastModifiedEpochMs': stat.modified.millisecondsSinceEpoch,
          });
        } catch (_) {
          // Fehlertoleranz bei gesperrten Dateien
        }
      }
    }
  }

  return found;
}

/// Rekursiver Hintergrund-Scanner fuer Audio-Formate mit Isolate-Traversierung
/// und inkrementeller Aenderungserkennung.
class LibraryScanner {
  const LibraryScanner();

  /// Scannt ein Verzeichnis asynchron in einem separaten Isolate.
  Future<List<ScannedAudioFile>> scanDirectory(
    String rootPath, {
    bool useIsolate = true,
  }) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      return [];
    }

    List<Map<String, dynamic>> rawList;
    if (useIsolate) {
      rawList = await Isolate.run(() => _traverseDirectoryInIsolate(rootPath));
    } else {
      rawList = _traverseDirectoryInIsolate(rootPath);
    }

    return rawList.map((m) => ScannedAudioFile.fromMap(m)).toList();
  }

  /// Scannt ein Verzeichnis reaktiv mit kontinuierlichen Fortschritts-Events.
  Stream<ScanProgress> scanDirectoryProgress(String rootPath) async* {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      yield ScanProgress(
        scannedFilesCount: 0,
        audioFilesFoundCount: 0,
        currentPath: rootPath,
        isCompleted: true,
      );
      return;
    }

    var scannedCount = 0;
    var audioFoundCount = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      scannedCount++;
      if (entity is File && AudioFormat.isSupported(entity.path)) {
        audioFoundCount++;
      }

      // Regelmaessige Fortschritts-Events an die UI senden
      if (scannedCount % 5 == 0 || audioFoundCount > 0) {
        yield ScanProgress(
          scannedFilesCount: scannedCount,
          audioFilesFoundCount: audioFoundCount,
          currentPath: entity.path,
          isCompleted: false,
        );
      }
    }

    // Abschluss-Event
    yield ScanProgress(
      scannedFilesCount: scannedCount,
      audioFilesFoundCount: audioFoundCount,
      currentPath: rootPath,
      isCompleted: true,
    );
  }

  /// Fuehrt einen inkrementellen Scan durch und ermittelt Neuzugaenge,
  /// Modifikationen und geloeschte Dateien im Vergleich zu [knownFiles].
  Future<ScanDiffResult> scanIncremental(
    String rootPath, {
    required List<ScannedAudioFile> knownFiles,
    bool useIsolate = true,
  }) async {
    final currentFiles = await scanDirectory(rootPath, useIsolate: useIsolate);

    final knownMap = <String, ScannedAudioFile>{
      for (final f in knownFiles) f.path: f,
    };
    final currentMap = <String, ScannedAudioFile>{
      for (final f in currentFiles) f.path: f,
    };

    final added = <ScannedAudioFile>[];
    final modified = <ScannedAudioFile>[];
    final unmodified = <ScannedAudioFile>[];
    final deletedPaths = <String>[];

    // Neue und veraenderte Dateien ermitteln
    for (final current in currentFiles) {
      final known = knownMap[current.path];
      if (known == null) {
        added.add(current);
      } else if (known.sizeBytes != current.sizeBytes ||
          known.lastModifiedEpochMs != current.lastModifiedEpochMs) {
        modified.add(current);
      } else {
        unmodified.add(current);
      }
    }

    // Geloeschte Dateien ermitteln
    for (final known in knownFiles) {
      if (!currentMap.containsKey(known.path)) {
        deletedPaths.add(known.path);
      }
    }

    return ScanDiffResult(
      addedFiles: added,
      modifiedFiles: modified,
      deletedFilePaths: deletedPaths,
      unmodifiedFiles: unmodified,
    );
  }
}
