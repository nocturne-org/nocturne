import 'dart:io';
import '../parser/media_metadata_parser.dart';
import '../scanner/audio_format.dart';
import 'organize_execution_result.dart';
import 'organize_plan_item.dart';
import 'path_sanitizer.dart';

/// Automatisches Sortier- und Verschiebe-Werkzeug nach dem Schema:
/// [targetLibraryDir] / [Autor] / [Buchname] / [Track - Titel.ext]
class SmartLibraryOrganizer {
  const SmartLibraryOrganizer({
    this.metadataParser = const MediaMetadataParser(),
  });

  final MediaMetadataParser metadataParser;

  /// Erstellt eine Vorschau (Dry-Run) aller geplanten Datei-Verschiebungen.
  Future<List<OrganizePlanItem>> planOrganization({
    required Directory sourceDirectory,
    required Directory targetLibraryDirectory,
  }) async {
    if (!await sourceDirectory.exists()) return [];

    final plan = <OrganizePlanItem>[];
    final entities = sourceDirectory.listSync(recursive: true, followLinks: false);

    for (final entity in entities) {
      if (entity is File && AudioFormat.isSupported(entity.path)) {
        final metadata = await metadataParser.parseFile(entity);

        final author = PathSanitizer.sanitize(
          metadata.author ?? '',
          fallback: 'Unbekannter Autor',
        );
        final book = PathSanitizer.sanitize(
          metadata.album ?? '',
          fallback: 'Unbekanntes Buch',
        );
        final title = PathSanitizer.sanitize(
          metadata.title,
          fallback: 'Track',
        );

        final ext = AudioFormat.fromPath(entity.path)?.extension ?? 'mp3';
        final trackPrefix = metadata.trackNumber != null
            ? '${metadata.trackNumber.toString().padLeft(2, '0')} - '
            : '';

        final fileName = '$trackPrefix$title.$ext';
        final separator = Platform.pathSeparator;
        final targetPath =
            '${targetLibraryDirectory.path}$separator$author$separator$book$separator$fileName';

        final isAlreadyOrganized = entity.path == targetPath;
        final isDuplicate = !isAlreadyOrganized && File(targetPath).existsSync();

        plan.add(
          OrganizePlanItem(
            sourcePath: entity.path,
            destinationPath: targetPath,
            author: author,
            book: book,
            title: title,
            trackNumber: metadata.trackNumber,
            isAlreadyOrganized: isAlreadyOrganized,
            isDuplicate: isDuplicate,
          ),
        );
      }
    }

    return plan;
  }

  /// Fuehrt den Organisationsplan atomar aus.
  /// Bei Fehlern werden saemtliche bereits verschobenen Dateien automatisch zurueckgerollt.
  Future<OrganizeExecutionResult> executePlan(
    List<OrganizePlanItem> plan, {
    bool skipDuplicates = true,
  }) async {
    final movedList = <(String source, String dest)>[];
    var skipped = 0;

    for (final item in plan) {
      if (item.isAlreadyOrganized) {
        skipped++;
        continue;
      }

      if (item.isDuplicate && skipDuplicates) {
        skipped++;
        continue;
      }

      final sourceFile = File(item.sourcePath);
      final destFile = File(item.destinationPath);

      try {
        if (!sourceFile.existsSync()) {
          throw FileSystemException('Source file does not exist', item.sourcePath);
        }

        // Zielordner anlegen
        if (!destFile.parent.existsSync()) {
          destFile.parent.createSync(recursive: true);
        }

        // Atomare Verschiebung mit Fallback auf Copy+Delete bei Partitionsgrenzen
        try {
          sourceFile.renameSync(item.destinationPath);
        } catch (_) {
          sourceFile.copySync(item.destinationPath);
          sourceFile.deleteSync();
        }

        movedList.add((item.sourcePath, item.destinationPath));
      } catch (e) {
        // Fehler aufgetreten -> Rollback aller bereits verschobenen Dateien
        var rolledBack = 0;
        for (final moved in movedList.reversed) {
          try {
            final f = File(moved.$2);
            if (f.existsSync()) {
              final original = File(moved.$1);
              if (!original.parent.existsSync()) {
                original.parent.createSync(recursive: true);
              }
              try {
                f.renameSync(moved.$1);
              } catch (_) {
                f.copySync(moved.$1);
                f.deleteSync();
              }
              rolledBack++;
            }
          } catch (_) {
            // Best-effort Rollback
          }
        }

        return OrganizeExecutionResult(
          success: false,
          movedCount: 0,
          skippedCount: skipped,
          rolledBackCount: rolledBack,
          errorMessage: 'Fehler bei Verschiebung von ${item.sourcePath}: $e',
        );
      }
    }

    return OrganizeExecutionResult(
      success: true,
      movedCount: movedList.length,
      skippedCount: skipped,
      rolledBackCount: 0,
    );
  }
}
