import 'package:flutter/services.dart';
import '../../domain/models/storage/saf_directory.dart';
import '../../domain/models/storage/saf_storage_exception.dart';
import 'saf_platform_interface.dart';

/// Platform-Adapter zur fehlerrobusten Kommunikation mit dem Android SAF.
/// Wandelt native PlatformExceptions in typisierte Domaenen-Ausnahmen um.
class SafStorageAdapter {
  SafStorageAdapter({required SafPlatformInterface platformInterface})
      : _platform = platformInterface;

  final SafPlatformInterface _platform;

  /// Oeffnet den System-Ordner-Picker und fordert persistierbare Berechtigungen an.
  Future<SafDirectory?> pickDirectory() async {
    try {
      final payload = await _platform.openDocumentTree();
      if (payload == null || payload.treeUri.isEmpty) {
        return null;
      }

      // Persistierung explizit bestaetigen
      final persisted =
          await _platform.takePersistableUriPermission(payload.treeUri);

      return SafDirectory(
        treeUri: payload.treeUri,
        displayName: payload.displayName,
        isPersisted: persisted,
        isAccessible: true,
        isExternalStorage: payload.isExternalStorage,
        lastValidated: DateTime.now(),
        status: SafDirectoryStatus.accessible,
        totalBytes: payload.totalBytes,
        freeBytes: payload.freeBytes,
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    } catch (e) {
      if (e is SafStorageException) rethrow;
      throw SafChannelException('Unerwarteter Fehler bei SAF-Auswahl: $e',
          cause: e);
    }
  }

  /// Fragt alle persistierten Ordner-Rechte vom System ab.
  Future<List<SafDirectory>> getPersistedDirectories() async {
    try {
      final payloads = await _platform.getPersistedUriPermissions();
      final now = DateTime.now();

      final results = <SafDirectory>[];
      for (final p in payloads) {
        final accessible = await _platform.isUriAccessible(p.treeUri);
        final status = accessible
            ? SafDirectoryStatus.accessible
            : (p.isExternalStorage
                ? SafDirectoryStatus.storageUnmounted
                : SafDirectoryStatus.directoryNotFound);

        results.add(
          SafDirectory(
            treeUri: p.treeUri,
            displayName: p.displayName,
            isPersisted: p.isPersisted,
            isAccessible: accessible,
            isExternalStorage: p.isExternalStorage,
            lastValidated: now,
            status: status,
            totalBytes: p.totalBytes,
            freeBytes: p.freeBytes,
          ),
        );
      }
      return results;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    } catch (e) {
      if (e is SafStorageException) rethrow;
      throw SafChannelException(
          'Fehler beim Abruf persistierter SAF-Rechte: $e',
          cause: e);
    }
  }

  /// Gibt eine persistierte Berechtigung frei.
  Future<bool> releasePersistedDirectory(String treeUri) async {
    try {
      return await _platform.releasePersistableUriPermission(treeUri);
    } on PlatformException catch (e) {
      throw _mapPlatformException(e, treeUri: treeUri);
    } catch (e) {
      if (e is SafStorageException) rethrow;
      throw SafChannelException(
        'Fehler bei Freigabe der Berechtigung fuer $treeUri: $e',
        treeUri: treeUri,
        cause: e,
      );
    }
  }

  /// Prueft den Zugriffszustand eines Verzeichnisses.
  Future<SafDirectoryStatus> verifyDirectoryAccess(
    String treeUri, {
    bool isExternalStorage = false,
  }) async {
    try {
      final isAccessible = await _platform.isUriAccessible(treeUri);
      if (isAccessible) {
        return SafDirectoryStatus.accessible;
      }

      // Falls nicht erreichbar: Speichermedium oder geloescht
      if (isExternalStorage) {
        return SafDirectoryStatus.storageUnmounted;
      }
      return SafDirectoryStatus.directoryNotFound;
    } on PlatformException catch (e) {
      if (e.code == 'SECURITY_EXCEPTION') {
        return SafDirectoryStatus.permissionRevoked;
      }
      if (e.code == 'STORAGE_UNMOUNTED') {
        return SafDirectoryStatus.storageUnmounted;
      }
      if (e.code == 'DIRECTORY_NOT_FOUND') {
        return SafDirectoryStatus.directoryNotFound;
      }
      return SafDirectoryStatus.unknownError;
    } catch (_) {
      return SafDirectoryStatus.unknownError;
    }
  }

  /// Liest Audio-Dateien im SAF-Baum aus.
  Future<List<SafFileItem>> listAudioFiles(
    String treeUri, {
    List<String> extensions = const ['mp3', 'm4b', 'm4a', 'flac', 'opus'],
  }) async {
    try {
      final filePayloads = await _platform.listFiles(treeUri, extensions);
      return filePayloads.map((f) {
        return SafFileItem(
          uri: f.uri,
          name: f.name,
          extension: f.extension.toLowerCase(),
          sizeBytes: f.sizeBytes,
          mimeType: f.mimeType,
          lastModified:
              DateTime.fromMillisecondsSinceEpoch(f.lastModifiedEpochMs),
        );
      }).toList();
    } on PlatformException catch (e) {
      throw _mapPlatformException(e, treeUri: treeUri);
    } catch (e) {
      if (e is SafStorageException) rethrow;
      throw SafChannelException(
        'Fehler beim Auflisten der Dateien in $treeUri: $e',
        treeUri: treeUri,
        cause: e,
      );
    }
  }

  SafStorageException _mapPlatformException(PlatformException e,
      {String? treeUri}) {
    final uri = treeUri ??
        (e.details is Map ? (e.details as Map)['treeUri'] as String? : null);
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return SafPermissionDeniedException(
          e.message ?? 'Berechtigung fuer SAF-Ordner verweigert.',
          treeUri: uri,
          cause: e,
        );
      case 'DIRECTORY_NOT_FOUND':
        return SafDirectoryNotFoundException(
          e.message ?? 'Das ausgewaehlte Verzeichnis wurde nicht gefunden.',
          treeUri: uri,
          cause: e,
        );
      case 'STORAGE_UNMOUNTED':
        return SafStorageUnavailableException(
          e.message ??
              'Das Speichermedium (z. B. SD-Karte) ist nicht verfuegbar.',
          treeUri: uri,
          cause: e,
        );
      case 'SECURITY_EXCEPTION':
        return SafSecurityException(
          e.message ??
              'Sicherheitsverletzung: Zugriff auf URI widerrufen oder abgelaufen.',
          treeUri: uri,
          cause: e,
        );
      default:
        return SafChannelException(
          e.message ??
              'Unbekannter Platformfehler im Storage Access Framework.',
          treeUri: uri,
          cause: e,
        );
    }
  }
}
