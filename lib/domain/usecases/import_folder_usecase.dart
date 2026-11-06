import 'dart:io';
import '../../data/datasources/database/daos/media_dao.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/scanner/audio_format.dart';
import '../models/audio/audio_source_ref.dart';
import '../models/media_item.dart';

/// Result of an import folder operation.
class ImportFolderResult {
  final String playlistId;
  final String playlistName;
  final int itemsCount;
  final List<MediaItem> importedItems;

  const ImportFolderResult({
    required this.playlistId,
    required this.playlistName,
    required this.itemsCount,
    required this.importedItems,
  });
}

/// Use case for scanning a local directory and creating an auto-playlist without auto-playback.
class ImportFolderUseCase {
  final MediaRepository? _mediaRepository;
  final MediaDao? _mediaDao;

  const ImportFolderUseCase({
    MediaRepository? mediaRepository,
    MediaDao? mediaDao,
  })  : _mediaRepository = mediaRepository,
        _mediaDao = mediaDao;

  /// Scans [directoryPath] recursively, creates a playlist named after the folder,
  /// saves all tracks to the database and adds them to the playlist.
  /// Completely silent (no auto-play).
  Future<ImportFolderResult> execute(String directoryPath) async {
    final cleanPath = directoryPath.trim();
    if (cleanPath.isEmpty) {
      throw ArgumentError('Directory path cannot be empty.');
    }

    final dir = Directory(cleanPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist.', cleanPath);
    }

    // Extract playlist name from directory basename
    final normalized = cleanPath.replaceAll(r'\', '/');
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    final folderName = segments.isNotEmpty ? segments.last : 'Imported Folder';

    // Scan recursively for supported audio files
    final audioFiles = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && AudioFormat.isSupported(entity.path)) {
        audioFiles.add(entity);
      }
    }

    // Sort files naturally by path
    audioFiles.sort((a, b) => a.path.compareTo(b.path));

    final mediaItems = <MediaItem>[];
    for (var i = 0; i < audioFiles.length; i++) {
      final file = audioFiles[i];
      final fileName = file.uri.pathSegments.last;
      final dotIndex = fileName.lastIndexOf('.');
      final title = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;

      final id = 'local_${file.path.hashCode.abs()}_$i';
      final item = MediaItem(
        id: id,
        title: title,
        type: MediaType.audiobook,
        source: AudioSourceRef.localFile(filePath: file.path),
        author: folderName,
        album: folderName,
      );
      mediaItems.add(item);
    }

    // Save media items to repository if available
    final mediaRepo = _mediaRepository;
    if (mediaRepo != null && mediaItems.isNotEmpty) {
      await mediaRepo.batchImportMedia(mediaItems);
    }

    // Create playlist and add items if dao is available
    String playlistId = 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    final dao = _mediaDao;
    if (dao != null) {
      final playlist = await dao.createPlaylist(
        folderName,
        kind: 'folder',
        sourcePath: cleanPath,
      );
      playlistId = playlist.id;

      if (mediaItems.isNotEmpty) {
        await dao.addItemsToPlaylist(
          playlistId,
          mediaItems.map((m) => m.id).toList(),
        );
      }
    }

    return ImportFolderResult(
      playlistId: playlistId,
      playlistName: folderName,
      itemsCount: mediaItems.length,
      importedItems: mediaItems,
    );
  }
}
