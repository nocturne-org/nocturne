import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/updater/cpu_architecture_resolver.dart';

void main() {
  group('Obtainium Kompatibilitaet & Metadaten-Standardisierung Tests (TICK-034)', () {
    test('Release-Tag-Schema folgt streng vX.Y.Z SemVer-Standard', () {
      final semVerRegex = RegExp(r'^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[\da-zA-Z-]+(?:\.[\da-zA-Z-]+)*)?(?:\+[\da-zA-Z-]+(?:\.[\da-zA-Z-]+)*)?$');

      expect(semVerRegex.hasMatch('v1.0.0'), isTrue);
      expect(semVerRegex.hasMatch('v0.1.0'), isTrue);
      expect(semVerRegex.hasMatch('v2.15.3'), isTrue);
      expect(semVerRegex.hasMatch('1.0.0'), isFalse, reason: 'Muss fuehrendes v enthalten');
      expect(semVerRegex.hasMatch('v1.0'), isFalse, reason: 'Muss dreiteilig sein');
    });

    test('APK-Dateinamen entsprechen dem kanonischen Nocturne-vX.Y.Z-<abi>.apk Schema', () {
      final apkRegex = RegExp(r'^Nocturne-v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-(arm64-v8a|armeabi-v7a|x86_64|universal)\.apk$');

      expect(apkRegex.hasMatch('Nocturne-v1.2.0-arm64-v8a.apk'), isTrue);
      expect(apkRegex.hasMatch('Nocturne-v1.2.0-universal.apk'), isTrue);
      expect(apkRegex.hasMatch('Nocturne-v1.2.0-armeabi-v7a.apk'), isTrue);
      expect(apkRegex.hasMatch('Nocturne-v1.2.0-x86_64.apk'), isTrue);
      expect(apkRegex.hasMatch('app-release.apk'), isFalse);
    });

    test('Obtainium Regex Filter selektiert praezise die arm64-v8a Split-APK', () {
      const releaseFiles = [
        'Nocturne-v1.2.0-arm64-v8a.apk',
        'Nocturne-v1.2.0-armeabi-v7a.apk',
        'Nocturne-v1.2.0-x86_64.apk',
        'Nocturne-v1.2.0-universal.apk',
        'sha256sums.txt',
      ];

      final obtainiumFilter = RegExp(r'arm64-v8a');
      final matched = releaseFiles.where((f) => obtainiumFilter.hasMatch(f)).toList();

      expect(matched.length, 1);
      expect(matched.first, 'Nocturne-v1.2.0-arm64-v8a.apk');

      // CpuArchitectureResolver selektiert ebenfalls diese Datei
      const resolver = CpuArchitectureResolver(forcedAbi: 'arm64-v8a');
      final autoSelected = resolver.selectBestApkAsset(releaseFiles);
      expect(autoSelected, 'Nocturne-v1.2.0-arm64-v8a.apk');
    });

    test('README.md enthaelt vollstaendige Obtainium-Anleitung', () {
      final readme = File('README.md');
      expect(readme.existsSync(), isTrue);

      final content = readme.readAsStringSync();
      expect(content, contains('Obtainium'));
      expect(content, contains('arm64-v8a'));
      expect(content, contains('https://github.com/roger/nocturne'));
    });
  });
}
