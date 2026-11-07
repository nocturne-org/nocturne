import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../platform/storage/path_sanitizer.dart';
import 'audio_format.dart';
import 'scan_diff_result.dart';
import 'scan_progress.dart';
import 'scan_result.dart';
import 'scanned_audio_file.dart';

export 'scan_result.dart';

/// Top-level function for background isolate directory traversal.
/// Scans directory recursively without blocking the main UI isolate.
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
          // Fault tolerance for locked or unreadable files
        }
      }
    }
  }

  // Ensure deterministic natural order sorted by file path
  found.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));

  return found;
}

/// Recursive background scanner for audio formats with isolate support,
/// explicit ScanResult error handling, and PathSanitizer defenses.
class LibraryScanner {
  /// Optional allowed roots for sandbox traversal validation.
  final List<String>? allowedRoots;

  const LibraryScanner({this.allowedRoots});

  /// Scans a directory asynchronously, validating against traversal attacks
  /// and returning an explicit [ScanResult].
  Future<ScanResult<List<ScannedAudioFile>>> scanDirectory(
    String rootPath, {
    bool useIsolate = true,
    List<String>? allowedRoots,
  }) async {
    final cleanPath = rootPath.trim();
    if (cleanPath.isEmpty) {
      return const ScanFailure(
        ScanException('Directory path cannot be empty.'),
      );
    }

    if (cleanPath.contains('\x00')) {
      return const ScanFailure(
        ScanException('Path contains invalid null byte.'),
      );
    }

    final effectiveRoots = allowedRoots ?? this.allowedRoots;
    if (effectiveRoots != null && effectiveRoots.isNotEmpty) {
      if (!PathSanitizer.isSafeWithinRoots(cleanPath, effectiveRoots)) {
        return ScanFailure(
          ScanException(
            'Path traversal detected: target "$cleanPath" is outside allowed roots.',
          ),
        );
      }
    }

    final dir = Directory(cleanPath);
    try {
      if (!await dir.exists()) {
        return ScanFailure(
          ScanException('Directory does not exist: $cleanPath'),
        );
      }
    } catch (e) {
      return ScanFailure(
        ScanException('Unable to access directory: $cleanPath', e),
      );
    }

    try {
      List<Map<String, dynamic>> rawList;
      if (useIsolate) {
        rawList =
            await Isolate.run(() => _traverseDirectoryInIsolate(cleanPath));
      } else {
        rawList = _traverseDirectoryInIsolate(cleanPath);
      }

      final scanned = rawList.map((m) => ScannedAudioFile.fromMap(m)).toList();
      return ScanSuccess(scanned);
    } catch (e) {
      return ScanFailure(
        ScanException('Scan error in directory: $cleanPath', e),
      );
    }
  }

  /// Scans a directory synchronously on the caller thread.
  ScanResult<List<ScannedAudioFile>> scanDirectorySync(
    String rootPath, {
    List<String>? allowedRoots,
  }) {
    final cleanPath = rootPath.trim();
    if (cleanPath.isEmpty) {
      return const ScanFailure(
        ScanException('Directory path cannot be empty.'),
      );
    }

    if (cleanPath.contains('\x00')) {
      return const ScanFailure(
        ScanException('Path contains invalid null byte.'),
      );
    }

    final effectiveRoots = allowedRoots ?? this.allowedRoots;
    if (effectiveRoots != null && effectiveRoots.isNotEmpty) {
      if (!PathSanitizer.isSafeWithinRoots(cleanPath, effectiveRoots)) {
        return ScanFailure(
          ScanException(
            'Path traversal detected: target "$cleanPath" is outside allowed roots.',
          ),
        );
      }
    }

    final dir = Directory(cleanPath);
    if (!dir.existsSync()) {
      return ScanFailure(
        ScanException('Directory does not exist: $cleanPath'),
      );
    }

    try {
      final rawList = _traverseDirectoryInIsolate(cleanPath);
      final scanned = rawList.map((m) => ScannedAudioFile.fromMap(m)).toList();
      return ScanSuccess(scanned);
    } catch (e) {
      return ScanFailure(
        ScanException('Scan error in directory: $cleanPath', e),
      );
    }
  }

  /// Scans a directory reactively with progress events.
  /// Throws [ScanException] if the directory path is invalid or non-existent.
  Stream<ScanProgress> scanDirectoryProgress(
    String rootPath, {
    List<String>? allowedRoots,
  }) async* {
    final cleanPath = rootPath.trim();
    if (cleanPath.isEmpty || cleanPath.contains('\x00')) {
      throw const ScanException('Invalid directory path.');
    }

    final effectiveRoots = allowedRoots ?? this.allowedRoots;
    if (effectiveRoots != null && effectiveRoots.isNotEmpty) {
      if (!PathSanitizer.isSafeWithinRoots(cleanPath, effectiveRoots)) {
        throw ScanException(
          'Path traversal detected: target "$cleanPath" is outside allowed roots.',
        );
      }
    }

    final dir = Directory(cleanPath);
    if (!await dir.exists()) {
      throw ScanException('Directory does not exist: $cleanPath');
    }

    var scannedCount = 0;
    var audioFoundCount = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      scannedCount++;
      if (entity is File && AudioFormat.isSupported(entity.path)) {
        audioFoundCount++;
      }

      if (scannedCount % 5 == 0 || audioFoundCount > 0) {
        yield ScanProgress(
          scannedFilesCount: scannedCount,
          audioFilesFoundCount: audioFoundCount,
          currentPath: entity.path,
          isCompleted: false,
        );
      }
    }

    yield ScanProgress(
      scannedFilesCount: scannedCount,
      audioFilesFoundCount: audioFoundCount,
      currentPath: cleanPath,
      isCompleted: true,
    );
  }

  /// Performs an incremental scan comparing discovered files against [knownFiles].
  /// Returns a [ScanResult] with [ScanDiffResult] on success or [ScanFailure] on failure.
  Future<ScanResult<ScanDiffResult>> scanIncremental(
    String rootPath, {
    required List<ScannedAudioFile> knownFiles,
    bool useIsolate = true,
    List<String>? allowedRoots,
  }) async {
    final scanRes = await scanDirectory(
      rootPath,
      useIsolate: useIsolate,
      allowedRoots: allowedRoots,
    );

    if (scanRes.isFailure) {
      return ScanFailure(scanRes.error!);
    }

    final currentFiles = scanRes.data;

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

    for (final known in knownFiles) {
      if (!currentMap.containsKey(known.path)) {
        deletedPaths.add(known.path);
      }
    }

    return ScanSuccess(ScanDiffResult(
      addedFiles: added,
      modifiedFiles: modified,
      deletedFilePaths: deletedPaths,
      unmodifiedFiles: unmodified,
    ));
  }
}
