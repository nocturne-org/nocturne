import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/scanner/audio_format.dart';
import 'package:nocturne/data/scanner/library_scanner.dart';

void main() {
  group('LibraryScanner & AudioFormat Tests (TICK-009)', () {
    late Directory tempRootDir;
    const scanner = LibraryScanner();

    setUp(() async {
      tempRootDir =
          await Directory.systemTemp.createTemp('nocturne_scanner_test_');

      // Verschachtelte Mock-Verzeichnisstruktur erstellen
      final book1Dir = Directory('${tempRootDir.path}/AuthorA/Book1');
      final book2Dir = Directory('${tempRootDir.path}/AuthorB/Book2/Subfolder');

      await book1Dir.create(recursive: true);
      await book2Dir.create(recursive: true);

      // Unterstuetzte Audio-Formate anlegen (.mp3, .m4b, .m4a, .flac, .opus)
      await File('${book1Dir.path}/track1.mp3')
          .writeAsBytes(List.filled(1000, 1));
      await File('${book1Dir.path}/track2.m4b')
          .writeAsBytes(List.filled(2000, 2));
      await File('${book2Dir.path}/track3.m4a')
          .writeAsBytes(List.filled(3000, 3));
      await File('${book2Dir.path}/track4.flac')
          .writeAsBytes(List.filled(4000, 4));
      await File('${book2Dir.path}/track5.opus')
          .writeAsBytes(List.filled(5000, 5));

      // Nicht-Audio-Dateien anlegen (duerfen nicht erfasst werden)
      await File('${book1Dir.path}/cover.jpg')
          .writeAsBytes(List.filled(500, 9));
      await File('${tempRootDir.path}/notes.txt').writeAsString('Notizen');
    });

    tearDown(() async {
      if (await tempRootDir.exists()) {
        await tempRootDir.delete(recursive: true);
      }
    });

    test(
        'AudioFormat erkennt alle gueltigen Endungen und ignoriert fremde Formate',
        () {
      expect(AudioFormat.fromPath('/path/to/file.mp3'), AudioFormat.mp3);
      expect(AudioFormat.fromPath('/path/to/file.M4B'), AudioFormat.m4b);
      expect(AudioFormat.fromPath('/path/to/file.m4a'), AudioFormat.m4a);
      expect(AudioFormat.fromPath('/path/to/file.aac'), AudioFormat.aac);
      expect(AudioFormat.fromPath('/path/to/file.flac'), AudioFormat.flac);
      expect(AudioFormat.fromPath('/path/to/file.opus'), AudioFormat.opus);
      expect(AudioFormat.fromPath('/path/to/file.ogg'), AudioFormat.ogg);
      expect(AudioFormat.fromPath('/path/to/file.wav'), AudioFormat.wav);

      expect(AudioFormat.fromPath('/path/to/cover.jpg'), isNull);
      expect(AudioFormat.fromPath('/path/to/notes.txt'), isNull);
      expect(AudioFormat.fromPath('/path/to/video.mp4'), isNull);
    });

    test(
        'scanDirectory findet rekursiv alle Audioformate und ignoriert Fremddateien',
        () async {
      final files =
          await scanner.scanDirectory(tempRootDir.path, useIsolate: false);

      expect(files.length, 5);

      final extensions = files.map((f) => f.format.extension).toSet();
      expect(extensions, containsAll(['mp3', 'm4b', 'm4a', 'flac', 'opus']));

      final names = files.map((f) => f.name).toSet();
      expect(names.contains('cover.jpg'), isFalse);
      expect(names.contains('notes.txt'), isFalse);
    });

    test('scanDirectoryProgress emittiert kontinuierliche Fortschritts-Events',
        () async {
      final events =
          await scanner.scanDirectoryProgress(tempRootDir.path).toList();

      expect(events.isNotEmpty, isTrue);

      final finalEvent = events.last;
      expect(finalEvent.isCompleted, isTrue);
      expect(finalEvent.audioFilesFoundCount, 5);
      expect(finalEvent.scannedFilesCount, greaterThanOrEqualTo(7));
    });

    test(
        'scanIncremental erkennt Neuzugaenge, Aenderungen und geloeschte Dateien',
        () async {
      // 1. Initialer Scan
      final initialFiles =
          await scanner.scanDirectory(tempRootDir.path, useIsolate: false);
      expect(initialFiles.length, 5);

      // 2. Modifikationen durchfuehren:
      // a) Neue Datei hinzufuegen
      final newFile = File('${tempRootDir.path}/AuthorA/Book1/track6_new.mp3');
      await newFile.writeAsBytes(List.filled(1500, 6));

      // b) Existierende Datei modifizieren (Groesse aendern)
      final modFile = File('${tempRootDir.path}/AuthorA/Book1/track1.mp3');
      await modFile.writeAsBytes(List.filled(8888, 8));

      // c) Eine Datei loeschen
      final delFile =
          File('${tempRootDir.path}/AuthorB/Book2/Subfolder/track5.opus');
      await delFile.delete();

      // 3. Inkrementellen Scan ausfuehren
      final diff = await scanner.scanIncremental(
        tempRootDir.path,
        knownFiles: initialFiles,
        useIsolate: false,
      );

      expect(diff.hasChanges, isTrue);
      expect(diff.addedFiles.length, 1);
      expect(diff.addedFiles.first.name, 'track6_new.mp3');

      expect(diff.modifiedFiles.length, 1);
      expect(diff.modifiedFiles.first.name, 'track1.mp3');

      expect(diff.deletedFilePaths.length, 1);
      expect(diff.deletedFilePaths.first, contains('track5.opus'));

      // 3 unveraenderte Dateien (track2.m4b, track3.m4a, track4.flac)
      expect(diff.unmodifiedFiles.length, 3);
      expect(diff.totalCurrentFiles, 5);
    });
  });
}
