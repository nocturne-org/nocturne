import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/config/sha256_digest.dart';
import 'package:nocturne/platform/updater/app_self_updater.dart';
import 'package:nocturne/platform/updater/app_update_info.dart';
import 'package:nocturne/platform/updater/cpu_architecture_resolver.dart';

class MockUpdateHttpTransport implements UpdateHttpTransport {
  MockUpdateHttpTransport({
    required this.jsonResponse,
    required this.sha256Response,
    this.simulatedApkBytes = const [
      0x50,
      0x4B,
      0x03,
      0x04
    ], // ZIP/APK Magic Bytes
  });

  final String jsonResponse;
  final String sha256Response;
  final List<int> simulatedApkBytes;

  @override
  Future<String> fetchString(String url) async {
    if (url.contains('sha256')) {
      return sha256Response;
    }
    return jsonResponse;
  }

  @override
  Future<void> downloadFile(
    String url,
    File targetFile, {
    void Function(int received, int total)? onProgress,
  }) async {
    await targetFile.writeAsBytes(simulatedApkBytes);
    if (onProgress != null) {
      onProgress(simulatedApkBytes.length, simulatedApkBytes.length);
    }
  }
}

class MockAndroidPackageInstaller implements AndroidPackageInstaller {
  File? installedFile;

  @override
  Future<bool> installPackage(File apkFile) async {
    installedFile = apkFile;
    return true;
  }
}

void main() {
  group('AppSelfUpdater Tests', () {
    late Directory tempDir;
    final simulatedBytes = [0x50, 0x4B, 0x03, 0x04, 0x00, 0x01];
    late String correctHash;

    const mockReleaseJson = '''{
  "tag_name": "v1.2.0",
  "body": "- Neuer AMOLED Timer\\n- Performance Fixes",
  "published_at": "2026-02-15T10:00:00Z",
  "assets": [
    {
      "name": "nocturne-arm64-v8a.apk",
      "size": 18500000,
      "browser_download_url": "https://github.com/roger/nocturne/releases/download/v1.2.0/nocturne-arm64-v8a.apk"
    },
    {
      "name": "nocturne-universal.apk",
      "size": 42000000,
      "browser_download_url": "https://github.com/roger/nocturne/releases/download/v1.2.0/nocturne-universal.apk"
    },
    {
      "name": "sha256sums.txt",
      "size": 250,
      "browser_download_url": "https://github.com/roger/nocturne/releases/download/v1.2.0/sha256sums.txt"
    }
  ]
}''';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('updater_test_');
      correctHash = Sha256Digest.computeBytesHash(simulatedBytes);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Semantic Version Comparison erkennt neuere Versionen', () {
      expect(AppUpdateInfo.compareVersions('v1.2.0', '1.1.0'), isTrue);
      expect(AppUpdateInfo.compareVersions('1.2.1', '1.2.0'), isTrue);
      expect(AppUpdateInfo.compareVersions('2.0.0', '1.9.9'), isTrue);
      expect(AppUpdateInfo.compareVersions('1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateInfo.compareVersions('1.0.0', '1.1.0'), isFalse);
    });

    test(
        'checkForUpdate parst GitHub Releases API und selektiert arm64-v8a APK',
        () async {
      final sha256Content = '$correctHash  nocturne-arm64-v8a.apk\n';
      final transport = MockUpdateHttpTransport(
        jsonResponse: mockReleaseJson,
        sha256Response: sha256Content,
        simulatedApkBytes: simulatedBytes,
      );

      final updater = AppSelfUpdater(
        transport: transport,
        archResolver: const CpuArchitectureResolver(forcedAbi: 'arm64-v8a'),
      );

      final update = await updater.checkForUpdate('1.0.0');

      expect(update, isNotNull);
      expect(update!.tagName, 'v1.2.0');
      expect(update.version, '1.2.0');
      expect(update.apkFileName, 'nocturne-arm64-v8a.apk');
      expect(update.expectedSha256, correctHash);
      expect(update.isNewerThanCurrent, isTrue);
    });

    test('downloadAndVerifyUpdate validiert Hash erfolgreich', () async {
      final sha256Content = '$correctHash  nocturne-arm64-v8a.apk\n';
      final transport = MockUpdateHttpTransport(
        jsonResponse: mockReleaseJson,
        sha256Response: sha256Content,
        simulatedApkBytes: simulatedBytes,
      );

      final updater = AppSelfUpdater(transport: transport);
      final updateInfo = AppUpdateInfo(
        tagName: 'v1.2.0',
        version: '1.2.0',
        apkDownloadUrl: 'https://example.com/app.apk',
        apkFileName: 'nocturne-arm64-v8a.apk',
        expectedSha256: correctHash,
      );

      final targetFile = File('${tempDir.path}/update.apk');
      final verifiedFile = await updater.downloadAndVerifyUpdate(
        update: updateInfo,
        targetApkFile: targetFile,
      );

      expect(await verifiedFile.exists(), isTrue);
      expect(await verifiedFile.readAsBytes(), simulatedBytes);
    });

    test(
        'downloadAndVerifyUpdate loescht Datei und wirft Fehler bei Hash-Mismatch',
        () async {
      const wrongHash =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final transport = MockUpdateHttpTransport(
        jsonResponse: mockReleaseJson,
        sha256Response: '',
        simulatedApkBytes: simulatedBytes,
      );

      final updater = AppSelfUpdater(transport: transport);
      final updateInfo = AppUpdateInfo(
        tagName: 'v1.2.0',
        version: '1.2.0',
        apkDownloadUrl: 'https://example.com/app.apk',
        apkFileName: 'nocturne-arm64-v8a.apk',
        expectedSha256: wrongHash, // Falscher Hash
      );

      final targetFile = File('${tempDir.path}/corrupt.apk');

      await expectLater(
        () => updater.downloadAndVerifyUpdate(
          update: updateInfo,
          targetApkFile: targetFile,
        ),
        throwsA(isA<StateError>()),
      );

      // Datei muss aus Sicherheitsgruenden geloescht worden sein
      expect(await targetFile.exists(), isFalse);
    });

    test('installUpdate startet Android Package Installer', () async {
      final mockInstaller = MockAndroidPackageInstaller();
      final updater = AppSelfUpdater(installer: mockInstaller);

      final apkFile = File('${tempDir.path}/ready.apk');
      await apkFile.writeAsBytes(simulatedBytes);

      final result = await updater.installUpdate(apkFile);

      expect(result, isTrue);
      expect(mockInstaller.installedFile?.path, apkFile.path);
    });
  });
}
