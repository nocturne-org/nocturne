import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/storage/sandbox_paths.dart';
import 'package:nocturne/platform/storage/sandbox_storage_provider.dart';

class MockStorageSpaceResolver implements StorageSpaceResolver {
  MockStorageSpaceResolver(this.freeSpace);
  int freeSpace;

  @override
  Future<int> getFreeDiskSpace(String path) async => freeSpace;
}

void main() {
  group('SandboxPaths Tests', () {
    test('Standard-Pfade und Konstanten sind korrekt definiert', () {
      expect(SandboxPaths.packageName, 'com.nocturne.audio');
      expect(SandboxPaths.defaultAndroidFilesDir,
          '/data/user/0/com.nocturne.audio/files');
      expect(SandboxPaths.audioDownloadsDir, 'audio_downloads');
      expect(SandboxPaths.podcastCacheDir, 'podcast_cache');
      expect(SandboxPaths.coverCacheDir, 'cover_cache');
      expect(SandboxPaths.partFileExtension, '.part');
      expect(SandboxPaths.noMediaFileName, '.nomedia');
      expect(SandboxPaths.minFreeSpaceWarningBytes, 500 * 1024 * 1024);
    });

    test('getSubdirectoryPath konstruiert Pfade plattformkonform', () {
      final base = Directory.systemTemp.path;
      final path = SandboxPaths.audioDownloadsPath(base);
      expect(path, contains('audio_downloads'));
      expect(path.startsWith(base), isTrue);
    });
  });

  group('SandboxStorageProvider Tests', () {
    late Directory tempDir;
    late SandboxStorageProvider provider;
    late MockStorageSpaceResolver mockResolver;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nocturne_sandbox_test_');
      mockResolver = MockStorageSpaceResolver(2 * 1024 * 1024 * 1024); // 2 GB
      provider = SandboxStorageProvider(
        baseDirectory: tempDir,
        spaceResolver: mockResolver,
      );
      await provider.initialize();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize erzeugt alle Kernverzeichnisse und Schutzdateien',
        () async {
      expect(await provider.audioDownloadsDirectory.exists(), isTrue);
      expect(await provider.podcastCacheDirectory.exists(), isTrue);
      expect(await provider.coverCacheDirectory.exists(), isTrue);

      // Schutz vor Android-Media-Indexierung und Cleanern
      final sep = Platform.pathSeparator;
      final audioNoMedia =
          File('${provider.audioDownloadsDirectory.path}$sep.nomedia');
      final podcastNoMedia =
          File('${provider.podcastCacheDirectory.path}$sep.nomedia');
      final coverNoMedia =
          File('${provider.coverCacheDirectory.path}$sep.nomedia');

      expect(await audioNoMedia.exists(), isTrue);
      expect(await podcastNoMedia.exists(), isTrue);
      expect(await coverNoMedia.exists(), isTrue);
    });

    test(
        'cleanupOrphanedPartFiles loescht nur .part-Dateien und meldet Bytes zurueck',
        () async {
      // 1. Gueltiges fertiges Audiofile erstellen
      final audioFile = provider.getAudioDownloadFile('fertiges_buch.m4b');
      await audioFile.writeAsBytes(List.filled(10000, 1));

      // 2. Verwaiste Download-Fragmente erstellen
      final part1 = provider.getAudioPartFile('abgebrochen_1.m4b');
      await part1.writeAsBytes(List.filled(15000, 2));

      final part2 = File(
          '${provider.podcastCacheDirectory.path}${Platform.pathSeparator}episode.mp3.part');
      await part2.writeAsBytes(List.filled(25000, 3));

      expect(await audioFile.exists(), isTrue);
      expect(await part1.exists(), isTrue);
      expect(await part2.exists(), isTrue);

      // Bereinigung durchfuehren
      final result = await provider.cleanupOrphanedPartFiles();

      expect(result.deletedFilesCount, 2);
      expect(result.reclaimedBytes, 40000);
      expect(await part1.exists(), isFalse);
      expect(await part2.exists(), isFalse);

      // Fertige Datei und .nomedia duerfen nicht geloescht werden
      expect(await audioFile.exists(), isTrue);
      final noMedia = File(
          '${provider.audioDownloadsDirectory.path}${Platform.pathSeparator}.nomedia');
      expect(await noMedia.exists(), isTrue);
    });

    test('checkStorageSpace liefert sufficient bei ausreichendem Speicher',
        () async {
      // 2 GB frei, 200 MB benoetigt -> Rest 1.8 GB (>= 500 MB)
      const free = 2 * 1024 * 1024 * 1024;
      const required = 200 * 1024 * 1024;

      final res = await provider.checkStorageSpace(
        requiredBytes: required,
        customFreeBytes: free,
      );

      expect(res.status, StorageSpaceStatus.sufficient);
      expect(res.canProceed, isTrue);
      expect(res.hasLowSpaceWarning, isFalse);
      expect(res.remainingBytesAfterDownload, free - required);
    });

    test(
        'checkStorageSpace liefert lowStorageWarning bei Restkapazitaet < 500 MB',
        () async {
      // 600 MB frei, 200 MB benoetigt -> Rest 400 MB (< 500 MB Schwellenwert)
      const free = 600 * 1024 * 1024;
      const required = 200 * 1024 * 1024;

      final res = await provider.checkStorageSpace(
        requiredBytes: required,
        customFreeBytes: free,
      );

      expect(res.status, StorageSpaceStatus.lowStorageWarning);
      expect(res.canProceed, isTrue);
      expect(res.hasLowSpaceWarning, isTrue);
      expect(res.remainingBytesAfterDownload, 400 * 1024 * 1024);
    });

    test('checkStorageSpace liefert insufficient bei unzureichendem Speicher',
        () async {
      // 100 MB frei, 500 MB benoetigt
      const free = 100 * 1024 * 1024;
      const required = 500 * 1024 * 1024;

      final res = await provider.checkStorageSpace(
        requiredBytes: required,
        customFreeBytes: free,
      );

      expect(res.status, StorageSpaceStatus.insufficient);
      expect(res.canProceed, isFalse);
      expect(res.hasLowSpaceWarning, isFalse);
    });

    test('clearCache bereinigt Cover und Podcasts, schuetzt jedoch Downloads',
        () async {
      final download = provider.getAudioDownloadFile('audiobook.m4b');
      await download.writeAsBytes(List.filled(20000, 1));

      final cover = provider.getCoverFile('cover_123');
      await cover.writeAsBytes(List.filled(5000, 2));

      final podcast = provider.getPodcastFile('episode_99.mp3');
      await podcast.writeAsBytes(List.filled(8000, 3));

      expect(await download.exists(), isTrue);
      expect(await cover.exists(), isTrue);
      expect(await podcast.exists(), isTrue);

      // Nur Covers leeren
      final reclaimedCovers = await provider.clearCache(
        includeCovers: true,
        includePodcasts: false,
      );
      expect(reclaimedCovers, 5000);
      expect(await cover.exists(), isFalse);
      expect(await podcast.exists(), isTrue);
      expect(await download.exists(), isTrue);

      // Auch Podcasts leeren
      final reclaimedPodcasts = await provider.clearCache(
        includeCovers: false,
        includePodcasts: true,
      );
      expect(reclaimedPodcasts, 8000);
      expect(await podcast.exists(), isFalse);
      expect(await download.exists(), isTrue);
    });

    test('getTotalSandboxSizeBytes berechnet die Groesse aller Dateien korrekt',
        () async {
      final f1 = provider.getAudioDownloadFile('track1.opus');
      await f1.writeAsBytes(List.filled(12000, 1));

      final f2 = provider.getCoverFile('art');
      await f2.writeAsBytes(List.filled(3000, 2));

      final total = await provider.getTotalSandboxSizeBytes();
      expect(total, greaterThanOrEqualTo(15000));
    });
  });
}
