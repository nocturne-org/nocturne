import '../../domain/models/storage/saf_directory.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../platform/saf/saf_storage_adapter.dart';

/// Clean Architecture Implementierung von [StorageRepository] fuer das Android SAF.
/// Kapselt den [SafStorageAdapter] und stellt Domaenenmodelle bereit.
class SafStorageRepositoryImpl implements StorageRepository {
  SafStorageRepositoryImpl({required SafStorageAdapter adapter})
      : _adapter = adapter;

  final SafStorageAdapter _adapter;

  @override
  Future<SafDirectory?> pickDirectory() async {
    return _adapter.pickDirectory();
  }

  @override
  Future<List<SafDirectory>> getPersistedDirectories() async {
    return _adapter.getPersistedDirectories();
  }

  @override
  Future<bool> releasePersistedDirectory(String treeUri) async {
    return _adapter.releasePersistedDirectory(treeUri);
  }

  @override
  Future<SafDirectoryStatus> verifyDirectoryAccess(String treeUri) async {
    // Abfragen, ob der Ordner als extern deklariert ist
    final directories = await _adapter.getPersistedDirectories();
    final match = directories.where((d) => d.treeUri == treeUri);
    final isExternal = match.isNotEmpty ? match.first.isExternalStorage : false;

    return _adapter.verifyDirectoryAccess(
      treeUri,
      isExternalStorage: isExternal,
    );
  }

  @override
  Future<List<SafFileItem>> listAudioFiles(
    String treeUri, {
    List<String> extensions = const ['mp3', 'm4b', 'm4a', 'flac', 'opus'],
  }) async {
    return _adapter.listAudioFiles(treeUri, extensions: extensions);
  }
}
