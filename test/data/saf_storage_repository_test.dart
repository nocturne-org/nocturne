import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/repositories/saf_storage_repository_impl.dart';
import 'package:nocturne/domain/models/storage/saf_directory.dart';
import 'package:nocturne/platform/saf/saf_platform_interface.dart';
import 'package:nocturne/platform/saf/saf_storage_adapter.dart';

class MockPlatformInterface implements SafPlatformInterface {
  SafNativeDirectoryPayload? pickResult;
  List<SafNativeDirectoryPayload> persistedList = [];
  bool isAccessible = true;
  bool releaseResult = true;
  List<SafNativeFilePayload> files = [];

  @override
  Future<SafNativeDirectoryPayload?> openDocumentTree() async => pickResult;

  @override
  Future<bool> takePersistableUriPermission(String uri) async => true;

  @override
  Future<bool> releasePersistableUriPermission(String uri) async =>
      releaseResult;

  @override
  Future<List<SafNativeDirectoryPayload>> getPersistedUriPermissions() async =>
      persistedList;

  @override
  Future<bool> isUriAccessible(String uri) async => isAccessible;

  @override
  Future<List<SafNativeFilePayload>> listFiles(
          String uri, List<String> extensions) async =>
      files;
}

void main() {
  group('SafStorageRepositoryImpl Tests', () {
    late MockPlatformInterface mockPlatform;
    late SafStorageAdapter adapter;
    late SafStorageRepositoryImpl repository;

    setUp(() {
      mockPlatform = MockPlatformInterface();
      adapter = SafStorageAdapter(platformInterface: mockPlatform);
      repository = SafStorageRepositoryImpl(adapter: adapter);
    });

    test('pickDirectory delegiert an Adapter und liefert SafDirectory',
        () async {
      mockPlatform.pickResult = const SafNativeDirectoryPayload(
        treeUri: 'content://tree/audio',
        displayName: 'Audiobooks',
        isPersisted: true,
        isExternalStorage: false,
      );

      final dir = await repository.pickDirectory();

      expect(dir, isNotNull);
      expect(dir!.displayName, 'Audiobooks');
      expect(dir.isPersisted, isTrue);
    });

    test(
        'verifyDirectoryAccess erkennt SD-Karten-Verlust anhand Persistenzdaten',
        () async {
      mockPlatform.persistedList = [
        const SafNativeDirectoryPayload(
          treeUri: 'content://tree/sdcard',
          displayName: 'SD Audio',
          isPersisted: true,
          isExternalStorage: true,
        ),
      ];
      mockPlatform.isAccessible = false;

      final status =
          await repository.verifyDirectoryAccess('content://tree/sdcard');

      expect(status, SafDirectoryStatus.storageUnmounted);
    });

    test('listAudioFiles reicht Dateiliste korrekt durch', () async {
      mockPlatform.files = [
        const SafNativeFilePayload(
          uri: 'content://f1',
          name: 'part1.opus',
          extension: 'opus',
          sizeBytes: 24000,
          mimeType: 'audio/ogg',
          lastModifiedEpochMs: 1680000000000,
        ),
      ];

      final list = await repository.listAudioFiles('content://tree/sdcard');

      expect(list.length, 1);
      expect(list.first.name, 'part1.opus');
      expect(list.first.extension, 'opus');
    });
  });
}
