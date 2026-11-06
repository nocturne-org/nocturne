/// Rohdaten-Transferobjekt aus dem nativen Android SAF Channel.
class SafNativeDirectoryPayload {
  const SafNativeDirectoryPayload({
    required this.treeUri,
    required this.displayName,
    required this.isPersisted,
    required this.isExternalStorage,
    this.totalBytes,
    this.freeBytes,
  });

  factory SafNativeDirectoryPayload.fromMap(Map<String, dynamic> map) {
    return SafNativeDirectoryPayload(
      treeUri: map['treeUri'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Unbekannter Ordner',
      isPersisted: map['isPersisted'] as bool? ?? false,
      isExternalStorage: map['isExternalStorage'] as bool? ?? false,
      totalBytes: (map['totalBytes'] as num?)?.toInt(),
      freeBytes: (map['freeBytes'] as num?)?.toInt(),
    );
  }

  final String treeUri;
  final String displayName;
  final bool isPersisted;
  final bool isExternalStorage;
  final int? totalBytes;
  final int? freeBytes;
}

/// Rohdaten-Transferobjekt fuer Dateien aus dem nativen SAF Channel.
class SafNativeFilePayload {
  const SafNativeFilePayload({
    required this.uri,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.mimeType,
    required this.lastModifiedEpochMs,
  });

  factory SafNativeFilePayload.fromMap(Map<String, dynamic> map) {
    return SafNativeFilePayload(
      uri: map['uri'] as String? ?? '',
      name: map['name'] as String? ?? '',
      extension: map['extension'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      lastModifiedEpochMs: (map['lastModified'] as num?)?.toInt() ?? 0,
    );
  }

  final String uri;
  final String name;
  final String extension;
  final int sizeBytes;
  final String mimeType;
  final int lastModifiedEpochMs;
}

/// Abstraktes Interface fuer die native Android Platform-Kommunikation.
abstract class SafPlatformInterface {
  /// Startet Intent.ACTION_OPEN_DOCUMENT_TREE und fordert Berechtigung.
  Future<SafNativeDirectoryPayload?> openDocumentTree();

  /// Persistiert Leserechte per ContentResolver.takePersistableUriPermission.
  Future<bool> takePersistableUriPermission(String uri);

  /// Gibt persistierte Leserechte per releasePersistableUriPermission frei.
  Future<bool> releasePersistableUriPermission(String uri);

  /// Fragt alle vom System persistierten URI-Permissions ab.
  Future<List<SafNativeDirectoryPayload>> getPersistedUriPermissions();

  /// Prueft ueber DocumentFile.fromTreeUri.exists() und canRead(), ob der URI lesbar ist.
  Future<bool> isUriAccessible(String uri);

  /// Liest Dateien mit den angegebenen Endungen aus dem SAF-Dokumentenbaum aus.
  Future<List<SafNativeFilePayload>> listFiles(
    String uri,
    List<String> extensions,
  );
}
