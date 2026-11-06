import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/storage/saf_directory.dart';
import 'package:nocturne/domain/models/storage/saf_storage_exception.dart';
import 'package:nocturne/platform/saf/saf_platform_interface.dart';
import 'package:nocturne/platform/saf/saf_storage_adapter.dart';

class MockSafPlatform implements SafPlatformInterface {
  SafNativeDirectoryPayload? mockPickResult;
  bool mockTakePermissionResult = true;
  bool mockReleaseResult = true;
  List<SafNativeDirectoryPayload> mockPersistedList = [];
  bool mockIsAccessible = true;
  List<SafNativeFilePayload> mockFileList = [];
  PlatformException? errorToThrow;

  @override
  Future<SafNativeDirectoryPayload?> openDocumentTree() async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockPickResult;
  }

  @override
  Future<bool> takePersistableUriPermission(String uri) async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockTakePermissionResult;
  }

  @override
  Future<bool> releasePersistableUriPermission(String uri) async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockReleaseResult;
  }

  @override
  Future<List<SafNativeDirectoryPayload>> getPersistedUriPermissions() async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockPersistedList;
  }

  @override
  Future<bool> isUriAccessible(String uri) async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockIsAccessible;
  }

  @override
  Future<List<SafNativeFilePayload>> listFiles(
    String uri,
    List<String> extensions,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return mockFileList;
  }
}

void main() {
  group('SafStorageAdapter Tests', () {
    late MockSafPlatform mockPlatform;
    late SafStorageAdapter adapter;

    setUp(() {
      mockPlatform = MockSafPlatform();
      adapter = SafStorageAdapter(platformInterface: mockPlatform);
    });

    test('pickDirectory liefert SafDirectory bei erfolgreicher Auswahl', () async {
      mockPlatform.mockPickResult = const SafNativeDirectoryPayload(
        treeUri: 'content://com.android.externalstorage.documents/tree/primary%3AAudiobooks',
        displayName: 'Audiobooks',
        isPersisted: true,
        isExternalStorage: false,
        totalBytes: 64000000000,
        freeBytes: 12000000000,
      );

      final result = await adapter.pickDirectory();

      expect(result, isNotNull);
      expect(result!.displayName, 'Audiobooks');
      expect(result.treeUri, contains('Audiobooks'));
      expect(result.isPersisted, isTrue);
      expect(result.isAccessible, isTrue);
      expect(result.status, SafDirectoryStatus.accessible);
    });

    test('pickDirectory liefert null bei Abbruch durch den Benutzer', () async {
      mockPlatform.mockPickResult = null;

      final result = await adapter.pickDirectory();

      expect(result, isNull);
    });

    test('pickDirectory wirft SafPermissionDeniedException bei Berechtigungsverweigerung', () async {
      mockPlatform.errorToThrow = PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'Berechtigung verweigert',
      );

      expect(
        () => adapter.pickDirectory(),
        throwsA(isA<SafPermissionDeniedException>()),
      );
    });

    test('getPersistedDirectories erkennt getrennte SD-Karten', () async {
      mockPlatform.mockPersistedList = [
        const SafNativeDirectoryPayload(
          treeUri: 'content://com.android.externalstorage.documents/tree/0000-0000%3ABooks',
          displayName: 'SD-Karte Hoerbuecher',
          isPersisted: true,
          isExternalStorage: true,
        ),
      ];
      // SD-Karte entfernt -> nicht zugaenglich
      mockPlatform.mockIsAccessible = false;

      final dirs = await adapter.getPersistedDirectories();

      expect(dirs.length, 1);
      expect(dirs.first.isExternalStorage, isTrue);
      expect(dirs.first.isAccessible, isFalse);
      expect(dirs.first.status, SafDirectoryStatus.storageUnmounted);
    });

    test('getPersistedDirectories erkennt geloeschte interne Ordner', () async {
      mockPlatform.mockPersistedList = [
        const SafNativeDirectoryPayload(
          treeUri: 'content://com.android.externalstorage.documents/tree/primary%3AGeloescht',
          displayName: 'Geloeschter Ordner',
          isPersisted: true,
          isExternalStorage: false,
        ),
      ];
      mockPlatform.mockIsAccessible = false;

      final dirs = await adapter.getPersistedDirectories();

      expect(dirs.length, 1);
      expect(dirs.first.isExternalStorage, isFalse);
      expect(dirs.first.status, SafDirectoryStatus.directoryNotFound);
    });

    test('releasePersistedDirectory gibt true bei Erfolg zurueck', () async {
      mockPlatform.mockReleaseResult = true;

      final success = await adapter.releasePersistedDirectory('content://test');
      expect(success, isTrue);
    });

    test('verifyDirectoryAccess liefert accessible wenn zugaenglich', () async {
      mockPlatform.mockIsAccessible = true;

      final status = await adapter.verifyDirectoryAccess('content://test');
      expect(status, SafDirectoryStatus.accessible);
    });

    test('listAudioFiles filtert Dateien und konvertiert Typen korrekt', () async {
      mockPlatform.mockFileList = [
        const SafNativeFilePayload(
          uri: 'content://file1',
          name: 'kapitel1.m4b',
          extension: 'm4b',
          sizeBytes: 150000000,
          mimeType: 'audio/mp4',
          lastModifiedEpochMs: 1700000000000,
        ),
        const SafNativeFilePayload(
          uri: 'content://file2',
          name: 'kapitel2.mp3',
          extension: 'MP3',
          sizeBytes: 45000000,
          mimeType: 'audio/mpeg',
          lastModifiedEpochMs: 1700000050000,
        ),
      ];

      final files = await adapter.listAudioFiles('content://test');

      expect(files.length, 2);
      expect(files[0].extension, 'm4b');
      expect(files[1].extension, 'mp3');
      expect(files[0].sizeBytes, 150000000);
    });
  });
}
