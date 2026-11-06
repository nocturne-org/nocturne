import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/domain/usecases/import_folder_usecase.dart';

void main() {
  group('ImportFolderUseCase Tests (TICK-V2-07)', () {
    late Directory tempDir;
    late AppDatabase db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nocturne_import_test_');
      db = AppDatabase.memory();

      // Create 8 supported audio files
      final extensions = ['mp3', 'm4b', 'm4a', 'aac', 'flac', 'opus', 'ogg', 'wav'];
      for (final ext in extensions) {
        final f = File('${tempDir.path}/track.$ext');
        await f.writeAsString('audio content dummy');
      }

      // Create non-audio files (should be ignored)
      await File('${tempDir.path}/cover.jpg').writeAsString('image');
      await File('${tempDir.path}/notes.txt').writeAsString('text');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Rejects empty path', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(() => useCase.execute('   '), throwsArgumentError);
    });

    test('Throws FileSystemException for non-existent path', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(
        () => useCase.execute('/non/existent/path/for/audiobooks'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('Recursively scans 8 audio formats and creates auto-playlist silently', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      final result = await useCase.execute(tempDir.path);

      // Verify all 8 files were discovered and non-audio ignored
      expect(result.itemsCount, 8);
      expect(result.importedItems.length, 8);

      // Verify playlist was created with folder name
      final playlists = await db.mediaDao.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.id, result.playlistId);

      // Verify playlist items
      final playlistItems = await db.mediaDao.getPlaylistItems(result.playlistId);
      expect(playlistItems.length, 8);
    });
  });
}
