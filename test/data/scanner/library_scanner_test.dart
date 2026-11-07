import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/database/app_database.dart';
import 'package:nocturne/data/scanner/audio_format.dart';
import 'package:nocturne/data/scanner/library_scanner.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/domain/usecases/import_folder_usecase.dart';

class _MockAudioPlayerRepository implements AudioPlayerRepository {
  final _statusCtrl = StreamController<AudioPlaybackStatus>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _volCtrl = StreamController<double>.broadcast();

  bool playCalled = false;
  AudioSourceRef? lastLoadedSource;
  Duration? lastInitialPosition;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    lastLoadedSource = source;
    lastInitialPosition = initialPosition;
  }

  @override
  Future<void> play() async {
    playCalled = true;
    _statusCtrl.add(AudioPlaybackStatus.playing);
  }

  @override
  Future<void> pause() async {
    _statusCtrl.add(AudioPlaybackStatus.paused);
  }

  @override
  Future<void> stop() async {
    _statusCtrl.add(AudioPlaybackStatus.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volCtrl.add(volume);
  }

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _volCtrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFormat 6-Core & 8-Format Support (TICK-V2-05)', () {
    test('Verifies 6 core audio formats are properly configured', () {
      expect(AudioFormat.coreSixFormats.length, 6);
      expect(AudioFormat.coreSixFormats, containsAll([
        AudioFormat.mp3,
        AudioFormat.m4b,
        AudioFormat.m4a,
        AudioFormat.aac,
        AudioFormat.ogg,
        AudioFormat.wav,
      ]));
    });

    test('Verifies all 8 audio extensions are supported case-insensitively', () {
      final formats = ['mp3', 'm4b', 'm4a', 'aac', 'flac', 'opus', 'ogg', 'wav'];
      for (final ext in formats) {
        expect(AudioFormat.isSupported('track.$ext'), isTrue);
        expect(AudioFormat.isSupported('folder/sub/TRACK.${ext.toUpperCase()}'), isTrue);
        expect(AudioFormat.fromPath('file.$ext'), isNotNull);
      }
      expect(AudioFormat.supportedExtensions, containsAll(formats));
    });

    test('Rejects non-audio file extensions', () {
      final unsupported = ['jpg', 'png', 'txt', 'nfo', 'pdf', 'mp4', 'mkv', 'zip'];
      for (final ext in unsupported) {
        expect(AudioFormat.isSupported('cover.$ext'), isFalse);
        expect(AudioFormat.fromPath('doc.$ext'), isNull);
      }
    });
  });

  group('LibraryScanner Recursive Traversal & Sorting (TICK-V2-05)', () {
    late Directory tempRootDir;
    const scanner = LibraryScanner();

    setUp(() async {
      tempRootDir = await Directory.systemTemp.createTemp('nocturne_scanner_v2_');

      // Create nested subfolder structure
      final albumDir = Directory('${tempRootDir.path}/SciFi/Dune/Disc1');
      await albumDir.create(recursive: true);

      // Create audio files with 6 formats
      await File('${albumDir.path}/01_intro.mp3').writeAsBytes(List.filled(500, 1));
      await File('${albumDir.path}/02_chapter.m4b').writeAsBytes(List.filled(600, 2));
      await File('${albumDir.path}/03_interlude.m4a').writeAsBytes(List.filled(700, 3));
      await File('${albumDir.path}/04_ambient.aac').writeAsBytes(List.filled(800, 4));
      await File('${albumDir.path}/05_dialogue.ogg').writeAsBytes(List.filled(900, 5));
      await File('${albumDir.path}/06_outro.wav').writeAsBytes(List.filled(1000, 6));

      // Create non-audio files
      await File('${albumDir.path}/cover.jpg').writeAsBytes(List.filled(200, 0));
      await File('${albumDir.path}/metadata.nfo').writeAsString('release metadata');
    });

    tearDown(() async {
      if (await tempRootDir.exists()) {
        await tempRootDir.delete(recursive: true);
      }
    });

    test('Recursively discovers 6 audio formats and excludes non-audio files', () async {
      final scanResult = await scanner.scanDirectory(tempRootDir.path, useIsolate: false);
      expect(scanResult.isSuccess, isTrue);

      final results = scanResult.data;
      expect(results.length, 6);
      final extensions = results.map((f) => f.format.extension).toList();
      expect(extensions, containsAll(['mp3', 'm4b', 'm4a', 'aac', 'ogg', 'wav']));

      final names = results.map((f) => f.name).toList();
      expect(names, contains('01_intro.mp3'));
      expect(names, contains('06_outro.wav'));
      expect(names.contains('cover.jpg'), isFalse);
      expect(names.contains('metadata.nfo'), isFalse);
    });

    test('Returns files sorted naturally in alphabetical path order', () async {
      final scanResult = await scanner.scanDirectory(tempRootDir.path, useIsolate: false);
      expect(scanResult.isSuccess, isTrue);

      final results = scanResult.data;
      expect(results.length, 6);

      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].path.compareTo(results[i + 1].path), lessThanOrEqualTo(0));
      }
    });

    test('Synchronous scanDirectorySync matches asynchronous scan results', () {
      final syncResult = scanner.scanDirectorySync(tempRootDir.path);
      expect(syncResult.isSuccess, isTrue);

      final syncResults = syncResult.data;
      expect(syncResults.length, 6);
      expect(syncResults.first.name, '01_intro.mp3');
      expect(syncResults.last.name, '06_outro.wav');
    });

    test('scanDirectoryProgress emits continuous events culminating in completion', () async {
      final events = await scanner.scanDirectoryProgress(tempRootDir.path).toList();
      expect(events.isNotEmpty, isTrue);

      final last = events.last;
      expect(last.isCompleted, isTrue);
      expect(last.audioFilesFoundCount, 6);
      expect(last.scannedFilesCount, greaterThanOrEqualTo(8));
    });

    test('scanIncremental correctly classifies added, modified, deleted, and unmodified files', () async {
      final initialResult = await scanner.scanDirectory(tempRootDir.path, useIsolate: false);
      expect(initialResult.isSuccess, isTrue);
      final initial = initialResult.data;
      expect(initial.length, 6);

      // Modify one file
      final modifiedFile = File('${tempRootDir.path}/SciFi/Dune/Disc1/01_intro.mp3');
      await modifiedFile.writeAsBytes(List.filled(2000, 99));

      // Add one new audio file
      final addedFile = File('${tempRootDir.path}/SciFi/Dune/Disc1/07_bonus.flac');
      await addedFile.writeAsBytes(List.filled(300, 7));

      // Delete one file
      final deletedFile = File('${tempRootDir.path}/SciFi/Dune/Disc1/06_outro.wav');
      await deletedFile.delete();

      final diffResult = await scanner.scanIncremental(
        tempRootDir.path,
        knownFiles: initial,
        useIsolate: false,
      );

      expect(diffResult.isSuccess, isTrue);
      final diff = diffResult.data;

      expect(diff.addedFiles.length, 1);
      expect(diff.addedFiles.first.name, '07_bonus.flac');

      expect(diff.modifiedFiles.length, 1);
      expect(diff.modifiedFiles.first.name, '01_intro.mp3');

      expect(diff.deletedFilePaths.length, 1);
      expect(diff.deletedFilePaths.first.endsWith('06_outro.wav'), isTrue);

      expect(diff.unmodifiedFiles.length, 4);
    });
  });

  group('ImportFolderUseCase Integration with SQLite & Instant Playback (TICK-V2-05)', () {
    late Directory tempDir;
    late AppDatabase db;
    late _MockAudioPlayerRepository mockPlayer;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nocturne_import_v2_');
      db = AppDatabase.memory();
      mockPlayer = _MockAudioPlayerRepository();

      // Create 6 core audio files in folder
      final coreExts = ['mp3', 'm4b', 'm4a', 'aac', 'ogg', 'wav'];
      for (var i = 0; i < coreExts.length; i++) {
        final f = File('${tempDir.path}/track_0${i + 1}.${coreExts[i]}');
        await f.writeAsString('audio content for track $i');
      }

      // Non-audio noise files
      await File('${tempDir.path}/folder.jpg').writeAsString('image');
      await File('${tempDir.path}/info.txt').writeAsString('text');
    });

    tearDown(() async {
      await mockPlayer.dispose();
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Imports 6 formats, persists auto-playlist in SQLite, and stays silent by default', () async {
      final useCase = ImportFolderUseCase(
        mediaDao: db.mediaDao,
        audioPlayerRepository: mockPlayer,
      );

      final result = await useCase.execute(tempDir.path, autoPlayFirstTrack: false);

      expect(result.itemsCount, 6);
      expect(result.importedItems.length, 6);
      expect(result.playbackStarted, isFalse);
      expect(mockPlayer.playCalled, isFalse);

      // Verify playlist in SQLite
      final playlists = await db.mediaDao.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, result.playlistName);
      expect(playlists.first.kind, 'folder');

      // Verify playlist items in SQLite
      final items = await db.mediaDao.getPlaylistItems(playlists.first.id);
      expect(items.length, 6);
    });

    test('Imports folder and immediately triggers playback of the first track when requested', () async {
      final useCase = ImportFolderUseCase(
        mediaDao: db.mediaDao,
        audioPlayerRepository: mockPlayer,
      );

      final result = await useCase.execute(tempDir.path, autoPlayFirstTrack: true);

      expect(result.itemsCount, 6);
      expect(result.playbackStarted, isTrue);
      expect(result.firstPlayedItem, isNotNull);
      expect(result.firstPlayedItem!.source.filePath, contains('track_01.mp3'));

      expect(mockPlayer.playCalled, isTrue);
      expect(mockPlayer.lastLoadedSource, isNotNull);
      expect(mockPlayer.lastLoadedSource!.filePath, contains('track_01.mp3'));
    });

    test('Convenience executeAndPlay triggers immediate playback', () async {
      final useCase = ImportFolderUseCase(
        mediaDao: db.mediaDao,
        audioPlayerRepository: mockPlayer,
      );

      final result = await useCase.executeAndPlay(tempDir.path);

      expect(result.playbackStarted, isTrue);
      expect(mockPlayer.playCalled, isTrue);
      expect(mockPlayer.lastLoadedSource!.filePath, contains('track_01.mp3'));
    });

    test('Throws ArgumentError on empty or whitespace path', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(() => useCase.execute(''), throwsArgumentError);
      expect(() => useCase.execute('   '), throwsArgumentError);
    });

    test('Throws FileSystemException on non-existent folder path', () async {
      final useCase = ImportFolderUseCase(mediaDao: db.mediaDao);
      expect(
        () => useCase.execute('/non/existent/test/path/directory'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
