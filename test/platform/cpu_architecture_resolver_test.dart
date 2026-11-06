import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/updater/cpu_architecture_resolver.dart';

void main() {
  group('CpuArchitectureResolver Tests', () {
    const assets = [
      'nocturne-arm64-v8a.apk',
      'nocturne-armeabi-v7a.apk',
      'nocturne-x86_64.apk',
      'nocturne-universal.apk',
      'sha256sums.txt',
    ];

    test('Bevorzugt arm64-v8a Split-APK bei 64-Bit ARM Geraeten', () {
      const resolver = CpuArchitectureResolver(forcedAbi: 'arm64-v8a');
      final selected = resolver.selectBestApkAsset(assets);
      expect(selected, 'nocturne-arm64-v8a.apk');
    });

    test('Waehlt armeabi-v7a bei 32-Bit ARM Geraeten', () {
      const resolver = CpuArchitectureResolver(forcedAbi: 'armeabi-v7a');
      final selected = resolver.selectBestApkAsset(assets);
      expect(selected, 'nocturne-armeabi-v7a.apk');
    });

    test('Waehlt x86_64 bei Android Emulator / Intel', () {
      const resolver = CpuArchitectureResolver(forcedAbi: 'x86_64');
      final selected = resolver.selectBestApkAsset(assets);
      expect(selected, 'nocturne-x86_64.apk');
    });

    test('Faellt auf Universal-APK zurueck wenn spezifische ABI fehlt', () {
      const resolver = CpuArchitectureResolver(forcedAbi: 'mips');
      const limitedAssets = [
        'nocturne-universal.apk',
        'sha256sums.txt',
      ];
      final selected = resolver.selectBestApkAsset(limitedAssets);
      expect(selected, 'nocturne-universal.apk');
    });
  });
}
