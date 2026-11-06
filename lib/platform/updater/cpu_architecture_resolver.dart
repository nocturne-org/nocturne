import 'dart:io';

/// Erkennung der nativen CPU-Architektur des Android-Geraets
/// zur Auswahl des optimalen Split-APKs (bevorzugt arm64-v8a mit ca. 18 MB).
class CpuArchitectureResolver {
  const CpuArchitectureResolver({
    String? forcedAbi,
  }) : _forcedAbi = forcedAbi;

  final String? _forcedAbi;

  /// Liefert die primaere CPU-ABI des Geraets.
  String getPrimaryAbi() {
    if (_forcedAbi != null && _forcedAbi!.isNotEmpty) {
      return _forcedAbi!;
    }

    // Android/Linux Standard: ABI aus Umgebung oder Systemarchitektur
    final arch = Platform.version.toLowerCase();
    if (arch.contains('arm64') || arch.contains('aarch64')) {
      return 'arm64-v8a';
    } else if (arch.contains('arm')) {
      return 'armeabi-v7a';
    } else if (arch.contains('x64') || arch.contains('x86_64')) {
      return 'x86_64';
    }

    // Standard-Default fuer moderne Android-Smartphones
    return 'arm64-v8a';
  }

  /// Waehlt das am besten passende Release-Asset aus einer Liste verfuegbarer Dateinamen aus.
  String selectBestApkAsset(List<String> availableFileNames) {
    final abi = getPrimaryAbi().toLowerCase();

    // 1. Spezifisches Split-APK fuer die Zielarchitektur suchen (z. B. Nocturne-v1.0.0-arm64-v8a.apk)
    final abiMatch = availableFileNames.firstWhere(
      (name) =>
          name.toLowerCase().contains(abi) &&
          name.toLowerCase().endsWith('.apk'),
      orElse: () => '',
    );
    if (abiMatch.isNotEmpty) {
      return abiMatch;
    }

    // 2. Fallback auf Universal-APK
    final universalMatch = availableFileNames.firstWhere(
      (name) =>
          name.toLowerCase().contains('universal') &&
          name.toLowerCase().endsWith('.apk'),
      orElse: () => '',
    );
    if (universalMatch.isNotEmpty) {
      return universalMatch;
    }

    // 3. Fallback auf beliebiges APK
    return availableFileNames.firstWhere(
      (name) => name.toLowerCase().endsWith('.apk'),
      orElse: () => '',
    );
  }
}
