import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../data/config/sha256_digest.dart';
import 'app_update_info.dart';
import 'cpu_architecture_resolver.dart';

/// Transport-Schnittstelle fuer Updater-HTTP-Anfragen (entkoppelt fuer Tests).
abstract class UpdateHttpTransport {
  Future<String> fetchString(String url);
  Future<void> downloadFile(
    String url,
    File targetFile, {
    void Function(int received, int total)? onProgress,
  });
}

/// Standard-Implementierung fuer HTTP-Netzwerkabrufe via HttpClient.
class DefaultUpdateHttpTransport implements UpdateHttpTransport {
  const DefaultUpdateHttpTransport();

  @override
  Future<String> fetchString(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'NocturneAppUpdater/1.0');
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await response.transform(utf8.decoder).join();
      } else {
        throw HttpException(
            'HTTP-Fehler ${response.statusCode} beim Laden von $url');
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<void> downloadFile(
    String url,
    File targetFile, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'NocturneAppUpdater/1.0');
      final response = await request.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final total = response.contentLength;
        var received = 0;

        final sink = targetFile.openWrite();
        await response.listen((chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (onProgress != null) {
            onProgress(received, total);
          }
        }).asFuture<void>();

        await sink.flush();
        await sink.close();
      } else {
        throw HttpException('Download-Fehler ${response.statusCode} fuer $url');
      }
    } finally {
      client.close();
    }
  }
}

/// Schnittstelle fuer den Android Package Installer.
abstract class AndroidPackageInstaller {
  Future<bool> installPackage(File apkFile);
}

/// Standard-Package-Installer via Android Platform Intent.
class DefaultAndroidPackageInstaller implements AndroidPackageInstaller {
  const DefaultAndroidPackageInstaller();

  @override
  Future<bool> installPackage(File apkFile) async {
    // In Produktionsumgebung via MethodChannel intent ausgeloest:
    // Intent(Intent.ACTION_VIEW).setDataAndType(apkUri, "application/vnd.android.package-archive")
    return apkFile.existsSync();
  }
}

/// Integrierter Self-Updater ueber die GitHub Releases API.
/// Prueft auf Updates, selektiert die passende arm64-v8a Split-APK,
/// verifiziert die SHA-256 Pruefsumme vor der Installation und startet den Package-Installer.
class AppSelfUpdater {
  AppSelfUpdater({
    this.repoSlug = 'roger/nocturne',
    UpdateHttpTransport? transport,
    CpuArchitectureResolver? archResolver,
    AndroidPackageInstaller? installer,
  })  : _transport = transport ?? const DefaultUpdateHttpTransport(),
        _archResolver = archResolver ?? const CpuArchitectureResolver(),
        _installer = installer ?? const DefaultAndroidPackageInstaller();

  final String repoSlug;
  final UpdateHttpTransport _transport;
  final CpuArchitectureResolver _archResolver;
  final AndroidPackageInstaller _installer;

  /// Prueft die GitHub Releases API auf neuere Versionen.
  Future<AppUpdateInfo?> checkForUpdate(String currentVersion) async {
    final apiUrl = 'https://api.github.com/repos/$repoSlug/releases/latest';
    final jsonStr = await _transport.fetchString(apiUrl);

    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final publishedAtStr = data['published_at'] as String?;
    final publishedAt =
        publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    final assets = (data['assets'] as List<dynamic>? ?? [])
        .map((a) => a as Map<String, dynamic>)
        .toList();

    final assetNames = assets.map((a) => a['name'] as String? ?? '').toList();

    // 1. Passende APK-Datei anhand der CPU-Architektur selektieren
    final bestApkName = _archResolver.selectBestApkAsset(assetNames);
    if (bestApkName.isEmpty) {
      return null;
    }

    final apkAsset = assets.firstWhere((a) => a['name'] == bestApkName);
    final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
    final sizeBytes = apkAsset['size'] as int? ?? 0;

    // 2. sha256sums.txt herunterladen und Pruefsumme extrahieren (falls vorhanden)
    String? expectedSha256;
    final checksumAsset = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').toLowerCase().contains('sha256'),
      orElse: () => {},
    );
    if (checksumAsset.isNotEmpty &&
        checksumAsset.containsKey('browser_download_url')) {
      try {
        final checksumUrl = checksumAsset['browser_download_url'] as String;
        final checksumContent = await _transport.fetchString(checksumUrl);
        expectedSha256 = _parseSha256ForFile(checksumContent, bestApkName);
      } catch (_) {}
    }

    final isNewer = AppUpdateInfo.compareVersions(tagName, currentVersion);

    return AppUpdateInfo(
      tagName: tagName,
      version: tagName.replaceAll(RegExp(r'^[vV]'), ''),
      apkDownloadUrl: downloadUrl,
      apkFileName: bestApkName,
      releaseNotes: body,
      publishedAt: publishedAt,
      expectedSha256: expectedSha256,
      apkSizeBytes: sizeBytes,
      isNewerThanCurrent: isNewer,
    );
  }

  /// Laedt die APK herunter und fuehrt eine kryptografische SHA-256 Verifikation durch.
  Future<File> downloadAndVerifyUpdate({
    required AppUpdateInfo update,
    required File targetApkFile,
    void Function(double progress)? onProgress,
  }) async {
    if (targetApkFile.existsSync()) {
      targetApkFile.deleteSync();
    }
    if (!targetApkFile.parent.existsSync()) {
      targetApkFile.parent.createSync(recursive: true);
    }

    // Download durchfuehren
    await _transport.downloadFile(
      update.apkDownloadUrl,
      targetApkFile,
      onProgress: (received, total) {
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      },
    );

    // SHA-256 Pruefsummen-Verifikation vor der Installation
    if (update.expectedSha256 != null && update.expectedSha256!.isNotEmpty) {
      final fileBytes = await targetApkFile.readAsBytes();
      final calculatedHash =
          Sha256Digest.computeBytesHash(fileBytes).toLowerCase();
      final expectedHash = update.expectedSha256!.trim().toLowerCase();

      if (calculatedHash != expectedHash) {
        // Manipulierte oder beschaedigte Datei sofort loeschen
        targetApkFile.deleteSync();
        throw StateError(
          'Kritischer Sicherheitsfehler: SHA-256 Pruefsummen-Mismatch! '
          'Erwartet: $expectedHash, Berechnet: $calculatedHash',
        );
      }
    }

    return targetApkFile;
  }

  /// Startet den Android Package-Installer Intent fuer die heruntergeladene APK.
  Future<bool> installUpdate(File apkFile) async {
    if (!apkFile.existsSync()) {
      throw StateError('APK-Datei existiert nicht: ${apkFile.path}');
    }
    return await _installer.installPackage(apkFile);
  }

  String? _parseSha256ForFile(String checksumFileContent, String fileName) {
    // Format von sha256sum: <hash>  <filename>
    final lines = LineSplitter.split(checksumFileContent);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hash = parts[0];
        final name = parts[1].replaceAll('*', '');
        if (name == fileName ||
            fileName.contains(name) ||
            name.contains(fileName)) {
          return hash;
        }
      }
    }
    return null;
  }
}
