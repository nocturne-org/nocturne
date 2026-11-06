import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/config/remote_config_engine.dart';
import 'package:nocturne/data/config/sha256_digest.dart';

class TestMockRemoteConfigClient implements RemoteConfigHttpClient {
  String? mockResponse;
  bool shouldThrow = false;

  @override
  Future<String> fetchRawConfig(String url) async {
    if (shouldThrow) {
      throw const SocketException('Keine Internetverbindung');
    }
    return mockResponse ??
        jsonEncode({
          'version': 2,
          'userAgent': 'Custom-User-Agent/2.0',
          'innertubeClientVersion': '2.20261105.02.00',
          'invidiousInstances': ['https://new.invidious.org'],
          'pipedInstances': ['https://new.piped.org'],
          'lastUpdated': '2026-11-06T10:00:00Z',
        });
  }
}

void main() {
  group('Tier 3: Remote Config Rule Engine Tests (TICK-022)', () {
    late Directory tempDir;
    late File cacheFile;
    late TestMockRemoteConfigClient mockClient;
    late RemoteConfigEngine engine;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nocturne_config_test_');
      cacheFile = File('${tempDir.path}/remote_config_cache.json');
      mockClient = TestMockRemoteConfigClient();
      engine = RemoteConfigEngine(
        cacheFile: cacheFile,
        httpClient: mockClient,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Initialer Start laedt Defaults, wenn noch kein Cache existiert', () {
      expect(engine.activeConfig.version, 1);
      expect(engine.activeConfig.innertubeClientVersion, '2.20261101.01.00');
      expect(engine.activeConfig.invidiousInstances.length, 2);
    });

    test(
        'fetchAndApplyConfig aktualisiert Parameter und schreibt persistenten Cache',
        () async {
      final config = await engine.fetchAndApplyConfig();

      expect(config.version, 2);
      expect(config.userAgent, 'Custom-User-Agent/2.0');
      expect(config.innertubeClientVersion, '2.20261105.02.00');
      expect(config.invidiousInstances, ['https://new.invidious.org']);

      // Cache-Datei muss nun auf der Festplatte existieren
      expect(await cacheFile.exists(), isTrue);
      final cacheContent = await cacheFile.readAsString();
      expect(cacheContent, contains('Custom-User-Agent/2.0'));

      // Neuer Engine-Start laedt die gecachte Konfiguration ohne Netzwerk
      final offlineEngine = RemoteConfigEngine(
        cacheFile: cacheFile,
        httpClient: TestMockRemoteConfigClient()..shouldThrow = true,
      );
      expect(offlineEngine.activeConfig.version, 2);
      expect(offlineEngine.activeConfig.userAgent, 'Custom-User-Agent/2.0');
    });

    test('SHA-256 Hash-Validierung erkennt manipulierte Payloads zuverlaessig',
        () async {
      final validJson = jsonEncode({
        'version': 3,
        'userAgent': 'Verified-Agent/3.0',
        'innertubeClientVersion': '2.20261106.01.00',
      });

      final validHash = Sha256Digest.computeHash(validJson);
      expect(validHash.length, 64);

      // 1. Gueltigen Hash uebergeben -> Erfolg
      final config = await engine.fetchAndApplyConfig(
        rawJsonOverride: validJson,
        expectedSha256: validHash,
      );
      expect(config.version, 3);
      expect(config.userAgent, 'Verified-Agent/3.0');

      // 2. Manipulierter Hash oder manipulierter Inhalt -> FormatException
      const tamperedHash =
          '0000000000000000000000000000000000000000000000000000000000000000';
      expect(
        () => engine.fetchAndApplyConfig(
          rawJsonOverride: validJson,
          expectedSha256: tamperedHash,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
