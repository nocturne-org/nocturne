import 'package:meta/meta.dart';

/// Status des Zugriffs auf ein persistiertes SAF-Verzeichnis.
enum SafDirectoryStatus {
  /// Verzeichnis existiert und Berechtigung ist aktiv.
  accessible,

  /// Die Berechtigung wurde vom Android-System oder Nutzer widerrufen.
  permissionRevoked,

  /// Das Speichermedium (z. B. SD-Karte) ist nicht mehr eingehaengt.
  storageUnmounted,

  /// Der Ordner wurde auf dem Dateisystem geloescht oder verschoben.
  directoryNotFound,

  /// Unerwarteter E/A- oder Systemfehler.
  unknownError,
}

/// Repraesentiert ein per Android Storage Access Framework (SAF) eingebundenes Verzeichnis.
@immutable
class SafDirectory {
  const SafDirectory({
    required this.treeUri,
    required this.displayName,
    this.isPersisted = true,
    this.isAccessible = true,
    this.isExternalStorage = false,
    required this.lastValidated,
    this.status = SafDirectoryStatus.accessible,
    this.fileCount,
    this.totalBytes,
    this.freeBytes,
  });

  /// Der persistierte Content-URI-String (content://com.android.externalstorage.documents/tree/...).
  final String treeUri;

  /// Vom Nutzer lesbarer Name des Ordners.
  final String displayName;

  /// Gibt an, ob takePersistableUriPermission erfolgreich persistiert wurde.
  final bool isPersisted;

  /// Zeigt an, ob das Verzeichnis aktuell lesbar und verfuegbar ist.
  final bool isAccessible;

  /// Markiert, ob der Pfad auf einer externen SD-Karte liegt.
  final bool isExternalStorage;

  /// Zeitpunkt der letzten Verifikation der Verzeichnis-Rechte.
  final DateTime lastValidated;

  /// Aktueller Status des SAF-Zugriffs.
  final SafDirectoryStatus status;

  /// Anzahl gefundener Audio-Dateien im Verzeichnis.
  final int? fileCount;

  /// Gesamtspeicherplatz des Speichervolumens in Bytes.
  final int? totalBytes;

  /// Verfuegbarer freier Speicherplatz des Speichervolumens in Bytes.
  final int? freeBytes;

  SafDirectory copyWith({
    String? treeUri,
    String? displayName,
    bool? isPersisted,
    bool? isAccessible,
    bool? isExternalStorage,
    DateTime? lastValidated,
    SafDirectoryStatus? status,
    int? fileCount,
    int? totalBytes,
    int? freeBytes,
  }) {
    return SafDirectory(
      treeUri: treeUri ?? this.treeUri,
      displayName: displayName ?? this.displayName,
      isPersisted: isPersisted ?? this.isPersisted,
      isAccessible: isAccessible ?? this.isAccessible,
      isExternalStorage: isExternalStorage ?? this.isExternalStorage,
      lastValidated: lastValidated ?? this.lastValidated,
      status: status ?? this.status,
      fileCount: fileCount ?? this.fileCount,
      totalBytes: totalBytes ?? this.totalBytes,
      freeBytes: freeBytes ?? this.freeBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafDirectory &&
          runtimeType == other.runtimeType &&
          treeUri == other.treeUri &&
          displayName == other.displayName &&
          isPersisted == other.isPersisted &&
          isAccessible == other.isAccessible &&
          isExternalStorage == other.isExternalStorage &&
          status == other.status;

  @override
  int get hashCode =>
      treeUri.hashCode ^
      displayName.hashCode ^
      isPersisted.hashCode ^
      isAccessible.hashCode ^
      isExternalStorage.hashCode ^
      status.hashCode;

  @override
  String toString() {
    return 'SafDirectory(name: $displayName, uri: $treeUri, status: $status, external: $isExternalStorage)';
  }
}

/// Repraesentiert eine einzelne Datei innerhalb eines SAF-Baumes.
@immutable
class SafFileItem {
  const SafFileItem({
    required this.uri,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.mimeType,
    required this.lastModified,
  });

  /// URI der konkreten Datei.
  final String uri;

  /// Dateiname inklusive Dateiendung.
  final String name;

  /// Dateiendung in Kleinbuchstaben (z. B. "mp3", "m4b").
  final String extension;

  /// Groesse der Datei in Bytes.
  final int sizeBytes;

  /// MIME-Type der Datei (z. B. "audio/mp4", "audio/mpeg").
  final String mimeType;

  /// Letztes Aenderungsdatum der Datei.
  final DateTime lastModified;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafFileItem &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => uri.hashCode ^ sizeBytes.hashCode;

  @override
  String toString() => 'SafFileItem(name: $name, size: $sizeBytes, uri: $uri)';
}
