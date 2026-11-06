import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHub Actions CI/CD Pipeline & Split APK Signing Tests (TICK-032)',
      () {
    test('release.yml erfuellt alle Akzeptanzkriterien', () {
      final file = File('.github/workflows/release.yml');
      expect(file.existsSync(), isTrue, reason: 'release.yml muss existieren');

      final content = file.readAsStringSync();

      // 1. Tag-Push Trigger
      expect(content, contains("tags:"),
          reason: 'Workflow muss auf Tags triggern');
      expect(content, contains("- 'v*'"),
          reason: 'Tags muessen v* entsprechen');

      // 2. Production Keystore Signing
      expect(content, contains('secrets.ANDROID_KEYSTORE_BASE64'),
          reason: 'Muss Keystore aus GitHub Secrets decodieren');
      expect(content, contains('key.properties'),
          reason: 'Muss key.properties konfigurieren');

      // 3. Split APK und Universal APK Build
      expect(content, contains('flutter build apk --release --split-per-abi'),
          reason: 'Muss Split-APKs bauen');
      expect(content, contains('flutter build apk --release'),
          reason: 'Muss Universal-APK bauen');
      expect(content, contains('app-arm64-v8a-release.apk'),
          reason: 'Muss arm64-v8a Split-APK verarbeiten');

      // 4. SHA-256 Pruefsummen
      expect(content, contains('sha256sum *.apk > sha256sums.txt'),
          reason: 'Muss SHA-256 Pruefsummen generieren');

      // 5. Release-Erstellung mit Release-Notes
      expect(content, contains('softprops/action-gh-release@v2'),
          reason: 'Muss softprops Release Action nutzen');
      expect(content, contains('generate_release_notes: true'),
          reason: 'Muss automatische Release-Notes generieren');
    });

    test('build.gradle.kts unterstuetzt Release-Keystore Signierung', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('key.properties'),
          reason: 'Muss key.properties laden');
      expect(content, contains('signingConfigs'),
          reason: 'Muss signingConfigs konfigurieren');
      expect(content, contains('create("release")'),
          reason: 'Muss release signingConfig erstellen');
    });

    test('ci.yml prueft Formatierung, Linting und Unit-Tests', () {
      final file = File('.github/workflows/ci.yml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('dart format'),
          reason: 'Muss Dart-Format pruefen');
      expect(content, contains('flutter analyze'),
          reason: 'Muss Linter ausfuehren');
      expect(content, contains('flutter test'),
          reason: 'Muss Tests ausfuehren');
    });
  });
}
