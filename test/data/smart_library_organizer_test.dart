import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/organizer/organize_plan_item.dart';
import 'package:nocturne/data/organizer/path_sanitizer.dart';
import 'package:nocturne/data/organizer/smart_library_organizer.dart';

void main() {
  group('Smart Library Auto-Organizer Tests (TICK-011)', () {
    late Directory tempSourceDir;
    late Directory tempTargetDir;
    const organizer = SmartLibraryOrganizer();

    setUp(() async {
      tempSourceDir =
          await Directory.systemTemp.createTemp('nocturne_organize_src_');
      tempTargetDir =
          await Directory.systemTemp.createTemp('nocturne_organize_dst_');
    });

    tearDown(() async {
      if (await tempSourceDir.exists()) {
        await tempSourceDir.delete(recursive: true);
      }
      if (await tempTargetDir.exists()) {
        await tempTargetDir.delete(recursive: true);
      }
    });

    test('PathSanitizer entfernt illegale Zeichen und normalisiert Pfade', () {
      expect(PathSanitizer.sanitize('Autor: Meister?'), 'Autor- Meister');
      expect(PathSanitizer.sanitize('Buch <Teil 1>'), 'Buch -Teil 1');
      expect(PathSanitizer.sanitize('Ordner...   '), 'Ordner');
      expect(PathSanitizer.sanitize('   '), 'Unbekannt');
      expect(PathSanitizer.sanitize('A/B\\C|D*E"F'), 'A-B-C-D-E-F');
    });

    test(
        'planOrganization erstellt Dry-Run Vorschau ohne Dateien zu verschieben',
        () async {
      // Unorganisierte Test-Dateien anlegen
      final f1 = File('${tempSourceDir.path}/01 - Die Gefaehrten.mp3');
      await f1.writeAsString('audio content 1');

      final f2 = File('${tempSourceDir.path}/Hesse - Siddhartha.m4b');
      await f2.writeAsString('audio content 2');

      final plan = await organizer.planOrganization(
        sourceDirectory: tempSourceDir,
        targetLibraryDirectory: tempTargetDir,
      );

      expect(plan.length, 2);

      // Quelldateien duerfen im Dry-Run nicht veraendert werden
      expect(await f1.exists(), isTrue);
      expect(await f2.exists(), isTrue);

      final item1 = plan.firstWhere(
        (p) =>
            p.sourcePath.replaceAll('/', '\\') == f1.path.replaceAll('/', '\\'),
      );
      expect(item1.trackNumber, 1);
      expect(item1.title, 'Die Gefaehrten');
      expect(item1.destinationPath, contains('Die Gefaehrten.mp3'));
      expect(item1.isAlreadyOrganized, isFalse);
      expect(item1.isDuplicate, isFalse);

      final item2 = plan.firstWhere(
        (p) =>
            p.sourcePath.replaceAll('/', '\\') == f2.path.replaceAll('/', '\\'),
      );
      expect(item2.author, 'Hesse');
      expect(item2.title, 'Siddhartha');
      expect(item2.destinationPath, contains('Hesse'));
      expect(item2.destinationPath, contains('Siddhartha.m4b'));
    });

    test('executePlan verschiebt unorganisierte Dateien in die Ziel-Hierarchie',
        () async {
      final f = File('${tempSourceDir.path}/05 - Kapitel 5.mp3');
      await f.writeAsString('track 5 content');

      final plan = await organizer.planOrganization(
        sourceDirectory: tempSourceDir,
        targetLibraryDirectory: tempTargetDir,
      );

      final result = await organizer.executePlan(plan);

      expect(result.success, isTrue);
      expect(result.movedCount, 1);
      expect(result.skippedCount, 0);

      // Quelldatei verschwunden
      expect(await f.exists(), isFalse);

      // Zieldatei an richtiger Stelle vorhanden
      final destPath = plan.first.destinationPath;
      final destFile = File(destPath);
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), 'track 5 content');
    });

    test('executePlan fuehrt bei Fehlern automatischen Rollback durch',
        () async {
      final f1 = File('${tempSourceDir.path}/trackA.mp3');
      await f1.writeAsString('content A');

      // Plan erzeugen, bei dem der zweite Eintrag auf einen unmoeglichen Pfad zeigt
      final plan = [
        OrganizePlanItem(
          sourcePath: f1.path,
          destinationPath: '${tempTargetDir.path}/ValidDir/trackA.mp3',
          author: 'Author',
          book: 'Book',
          title: 'Track A',
        ),
        OrganizePlanItem(
          sourcePath: '${tempSourceDir.path}/non_existent.mp3',
          destinationPath: '${tempTargetDir.path}/InvalidDir/\x00illegal.mp3',
          author: 'Author',
          book: 'Book',
          title: 'Track B',
        ),
      ];

      // Ausfuehrung mit absichtlichem Fehler
      final result = await organizer.executePlan(plan);

      // Rollback verifizieren
      expect(result.success, isFalse);
      expect(result.rolledBackCount, 1);

      // f1 muss wieder am Urspruenglichen Quellort liegen
      expect(await f1.exists(), isTrue);
      expect(await f1.readAsString(), 'content A');
    });
  });
}
