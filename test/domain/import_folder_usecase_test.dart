import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/import_folder_usecase.dart';
import 'package:nocturne/platform/storage/path_sanitizer.dart';

class FakeAudioPlayer implements AudioPlayerRepository {
  AudioSourceRef? currentSource;
  bool isPlaying = false;
  int playCallCount = 0;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<double> get volumeStream => const Stream.empty();

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    currentSource = source;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playCallCount++;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ImportFolderUseCase Tests (TICK-V2-05)', () {
    late Directory tempDir;
    late AppDatabase db;
    late FakeAudioPlayer fakeAudioPlayer;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nocturne_import_test_');
      db = AppDatabase.memory();
      fakeAudioPlayer = FakeAudioPlayer();

      // Create 8 supported audio files (AAC, OGG, WAV, MP3, M4B, M4A, FLAC, OPUS)
      final extensions = [
        'mp3',
        'm4b',
        'm4a',
        'aac',
        'flac',
        'opus',
        'ogg',
        'wav',
      ];
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

    test('Rejects empty path with ArgumentError', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(() => useCase.execute('   '), throwsArgumentError);
    });

    test('Defends against null-byte injection with SecurityException', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(
        () => useCase.execute('${tempDir.path}\x00/evil'),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Defends against path traversal with SecurityException when allowedRoots are provided', () async {
      final subDir = Directory('${tempDir.path}/sub');
      await subDir.create();
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);

      expect(
        () => useCase.execute(
          '${subDir.path}/../',
          allowedRoots: [subDir.path],
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Throws FileSystemException for non-existent path', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(
        () => useCase.execute('/non/existent/path/for/audiobooks'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('Recursively scans 8 audio formats and creates auto-playlist silently', () async {
      final useCase = ImportFolderUseCase(
        mediaDao: db.mediaDao,
        audioPlayer: fakeAudioPlayer,
      );
      final result = await useCase.execute(tempDir.path);

      // Verify all 8 files were discovered and non-audio ignored
      expect(result.itemsCount, 8);
      expect(result.importedItems.length, 8);
      expect(result.startItem, isNotNull);
      expect(fakeAudioPlayer.isPlaying, isFalse);

      // Verify playlist was created with folder name
      final playlists = await db.mediaDao.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.id, result.playlistId);

      // Verify playlist items
      final playlistItems = await db.mediaDao.getPlaylistItems(result.playlistId);
      expect(playlistItems.length, 8);
    });

    test('Reuses existing playlist when folder is imported again', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);

      // First import
      final firstResult = await useCase.execute(tempDir.path);

      // Second import of same path
      final secondResult = await useCase.execute(tempDir.path);

      expect(secondResult.playlistId, firstResult.playlistId);

      final playlists = await db.mediaDao.getPlaylists();
      expect(playlists.length, 1);
    });

    test('Supports immediate playback of first track when autoPlay is true', () async {
      final useCase = ImportFolderUseCase(
        mediaDao: db.mediaDao,
        audioPlayer: fakeAudioPlayer,
      );

      final result = await useCase.execute(tempDir.path, autoPlay: true);

      expect(result.itemsCount, 8);
      expect(result.startItem, isNotNull);
      expect(fakeAudioPlayer.isPlaying, isTrue);
      expect(fakeAudioPlayer.playCallCount, 1);
      expect(fakeAudioPlayer.currentSource, result.startItem!.source);
    });
  });
}
