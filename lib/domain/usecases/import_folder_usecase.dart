import 'dart:io';
import '../../data/datasources/database/daos/media_dao.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/scanner/library_scanner.dart';
import '../../platform/storage/path_sanitizer.dart';
import '../models/audio/audio_source_ref.dart';
import '../models/media_item.dart';
import '../repositories/audio_player_repository.dart';

/// Result of an import folder operation.
class ImportFolderResult {
  final String playlistId;
  final String playlistName;
  final int itemsCount;
  final List<MediaItem> importedItems;
  final MediaItem? startItem;
  final bool playbackStarted;

  const ImportFolderResult({
    required this.playlistId,
    required this.playlistName,
    required this.itemsCount,
    required this.importedItems,
    this.startItem,
    this.playbackStarted = false,
  });

  /// Alias for the first played item when playback was started.
  MediaItem? get firstPlayedItem => startItem;
}

/// Use case for scanning a local directory, creating or reusing an auto-playlist,
/// and optionally starting immediate playback of the first item.
class ImportFolderUseCase {
  final MediaRepository? _mediaRepository;
  final MediaDao? _mediaDao;
  final AudioPlayerRepository? _audioPlayer;
  final LibraryScanner _scanner;

  const ImportFolderUseCase({
    MediaRepository? mediaRepository,
    MediaDao? mediaDao,
    AudioPlayerRepository? audioPlayer,
    AudioPlayerRepository? audioPlayerRepository,
    LibraryScanner scanner = const LibraryScanner(),
  })  : _mediaRepository = mediaRepository,
        _mediaDao = mediaDao,
        _audioPlayer = audioPlayer ?? audioPlayerRepository,
        _scanner = scanner;

  /// Scans [directoryPath] recursively, creates or reuses an auto-playlist named after the folder,
  /// persists all discovered audio tracks to the database and adds them to the playlist.
  /// When [autoPlay] or [autoPlayFirstTrack] is true, immediately initiates playback of the first track.
  Future<ImportFolderResult> execute(
    String directoryPath, {
    bool autoPlay = false,
    bool? autoPlayFirstTrack,
    List<String>? allowedRoots,
  }) async {
    final cleanPath = directoryPath.trim();
    if (cleanPath.isEmpty) {
      throw ArgumentError('Directory path cannot be empty.');
    }

    if (cleanPath.contains('\x00')) {
      throw const SecurityException('Path contains invalid null byte');
    }

    final effectiveRoots = allowedRoots ?? _scanner.allowedRoots;
    if (effectiveRoots != null && effectiveRoots.isNotEmpty) {
      if (!PathSanitizer.isSafeWithinRoots(cleanPath, effectiveRoots)) {
        throw SecurityException(
          'Path traversal detected: target "$cleanPath" is outside allowed roots.',
        );
      }
    }

    final dir = Directory(cleanPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist.', cleanPath);
    }

    // Extract playlist name from directory basename
    final normalized = cleanPath.replaceAll(r'\', '/');
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    final folderName = segments.isNotEmpty ? segments.last : 'Imported Folder';

    // Scan recursively using LibraryScanner
    final scanResult = await _scanner.scanDirectory(
      cleanPath,
      useIsolate: false,
      allowedRoots: effectiveRoots,
    );

    if (scanResult.isFailure) {
      throw FileSystemException(scanResult.error!.message, cleanPath);
    }

    final scannedFiles = scanResult.data;
    // Sort files naturally by path
    scannedFiles.sort((a, b) => a.path.compareTo(b.path));

    final mediaItems = <MediaItem>[];
    for (var i = 0; i < scannedFiles.length; i++) {
      final file = scannedFiles[i];
      final fileName = file.name;
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

    // Persist media items to repository or DAO
    final mediaRepo = _mediaRepository;
    final dao = _mediaDao;
    if (mediaRepo != null && mediaItems.isNotEmpty) {
      await mediaRepo.batchImportMedia(mediaItems);
    } else if (dao != null && mediaItems.isNotEmpty) {
      for (final item in mediaItems) {
        await dao.upsertMediaItem(item);
      }
    }

    // Create or reuse playlist and register items
    String playlistId = 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    if (dao != null) {
      final existingPlaylists = await dao.getPlaylists();
      PlaylistEntry? existing;
      for (final p in existingPlaylists) {
        if (p.sourcePath == cleanPath || p.name == folderName) {
          existing = p;
          break;
        }
      }

      if (existing != null) {
        playlistId = existing.id;
      } else {
        final playlist = await dao.createPlaylist(
          folderName,
          kind: 'folder',
          sourcePath: cleanPath,
        );
        playlistId = playlist.id;
      }

      if (mediaItems.isNotEmpty) {
        await dao.addItemsToPlaylist(
          playlistId,
          mediaItems.map((m) => m.id).toList(),
        );
      }
    }

    // Support immediate playback of the start item
    final startItem = mediaItems.isNotEmpty ? mediaItems.first : null;
    final shouldPlay = autoPlayFirstTrack ?? autoPlay;
    var playbackStarted = false;
    final audioPlayer = _audioPlayer;
    if (shouldPlay && startItem != null && audioPlayer != null) {
      await audioPlayer.setSource(startItem.source);
      await audioPlayer.play();
      playbackStarted = true;
    }

    return ImportFolderResult(
      playlistId: playlistId,
      playlistName: folderName,
      itemsCount: mediaItems.length,
      importedItems: mediaItems,
      startItem: startItem,
      playbackStarted: playbackStarted,
    );
  }

  /// Convenience method that imports the folder and immediately starts playback.
  Future<ImportFolderResult> executeAndPlay(
    String directoryPath, {
    List<String>? allowedRoots,
  }) =>
      execute(directoryPath, autoPlay: true, allowedRoots: allowedRoots);
}
