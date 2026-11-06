/// Modell fuer verfuegbare Release-Informationen aus der GitHub Releases API.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.apkDownloadUrl,
    required this.apkFileName,
    this.releaseNotes = '',
    this.publishedAt,
    this.expectedSha256,
    this.apkSizeBytes = 0,
    this.isNewerThanCurrent = false,
  });

  /// Versions-Tag (z. B. "v1.2.0").
  final String tagName;

  /// Bereinigte Versionsnummer (z. B. "1.2.0").
  final String version;

  /// Direkte Download-URL des passenden APK-Artefakts.
  final String apkDownloadUrl;

  /// Dateiname des APKs (z. B. "nocturne-arm64-v8a.apk").
  final String apkFileName;

  /// Changelog / Veroeffentlichungsnotizen.
  final String releaseNotes;

  /// Zeitpunkt der Veroeffentlichung auf GitHub.
  final DateTime? publishedAt;

  /// Erwarteter SHA-256 Hash aus sha256sums.txt.
  final String? expectedSha256;

  /// Dateigroesse in Bytes.
  final int apkSizeBytes;

  /// Ob dieses Release neuer ist als die aktuell installierte Version.
  final bool isNewerThanCurrent;

  /// Vergleicht zwei semantische Versionen ("major.minor.patch").
  /// Liefert true zurueck, falls die vorliegende Version neuer ist als [currentVersion].
  static bool compareVersions(String remoteVersion, String currentVersion) {
    final cleanRemote = remoteVersion.replaceAll(RegExp(r'^[vV]'), '').trim();
    final cleanCurrent = currentVersion.replaceAll(RegExp(r'^[vV]'), '').trim();

    final rParts = cleanRemote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final cParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (rParts.length < 3) {
      rParts.add(0);
    }
    while (cParts.length < 3) {
      cParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (rParts[i] > cParts[i]) return true;
      if (rParts[i] < cParts[i]) return false;
    }

    return false;
  }

  AppUpdateInfo copyWith({
    String? tagName,
    String? version,
    String? apkDownloadUrl,
    String? apkFileName,
    String? releaseNotes,
    DateTime? publishedAt,
    String? expectedSha256,
    int? apkSizeBytes,
    bool? isNewerThanCurrent,
  }) {
    return AppUpdateInfo(
      tagName: tagName ?? this.tagName,
      version: version ?? this.version,
      apkDownloadUrl: apkDownloadUrl ?? this.apkDownloadUrl,
      apkFileName: apkFileName ?? this.apkFileName,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      publishedAt: publishedAt ?? this.publishedAt,
      expectedSha256: expectedSha256 ?? this.expectedSha256,
      apkSizeBytes: apkSizeBytes ?? this.apkSizeBytes,
      isNewerThanCurrent: isNewerThanCurrent ?? this.isNewerThanCurrent,
    );
  }

  @override
  String toString() =>
      'AppUpdateInfo(version: $version, apk: $apkFileName, newer: $isNewerThanCurrent)';
}
