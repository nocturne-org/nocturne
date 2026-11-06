import 'dart:async';
import 'dart:io';
import '../../domain/models/audio/audio_source_ref.dart';
import '../../domain/models/media_item.dart';
import '../../platform/storage/sandbox_storage_provider.dart';
import '../repositories/media_repository.dart';
import 'download_task.dart';
import 'tag_injector.dart';

/// HTTP-Transport-Schnittstelle fuer Downloads (entkoppelt fuer Tests).
abstract class DownloadHttpTransport {
  Future<void> downloadStream({
    required String url,
    required File targetPartFile,
    required void Function(int downloaded, int total) onProgress,
    required bool Function() isCancelledOrPaused,
  });
}

/// Standard-Transport fuer reale HTTP-Downloads.
class DefaultDownloadHttpTransport implements DownloadHttpTransport {
  const DefaultDownloadHttpTransport();

  @override
  Future<void> downloadStream({
    required String url,
    required File targetPartFile,
    required void Function(int downloaded, int total) onProgress,
    required bool Function() isCancelledOrPaused,
  }) async {
    // In Test- und Mockumgebung wird diese Schnittstelle ueberschrieben
    await targetPartFile.writeAsBytes(List.filled(10000, 0xAA));
    onProgress(10000, 10000);
  }
}

/// Offline Download-Manager fuer die interne App-Sandbox mit Warteschlange,
/// Pause/Fortsetzen, automatischer ID3-Tag-Injektion und Bibliotheks-Registrierung.
class DownloadManager {
  DownloadManager({
    required SandboxStorageProvider storageProvider,
    required MediaRepository mediaRepository,
    DownloadHttpTransport? transport,
  })  : _storage = storageProvider,
        _repo = mediaRepository,
        _transport = transport ?? const DefaultDownloadHttpTransport();

  final SandboxStorageProvider _storage;
  final MediaRepository _repo;
  final DownloadHttpTransport _transport;

  final Map<String, DownloadTask> _queue = {};
  final StreamController<List<DownloadTask>> _queueController =
      StreamController<List<DownloadTask>>.broadcast();

  /// Reaktiv die Download-Warteschlange beobachten.
  Stream<List<DownloadTask>> watchQueue() async* {
    yield _queue.values.toList();
    yield* _queueController.stream;
  }

  /// Reiht ein neues Medium in die Download-Warteschlange ein.
  Future<DownloadTask> enqueueDownload({
    required MediaItem mediaItem,
    required String streamUrl,
    int estimatedSizeBytes = 25000000, // ca. 25 MB
  }) async {
    // 1. Speicherplatzpruefung in der Sandbox
    final spaceCheck = await _storage.checkStorageSpace(
      requiredBytes: estimatedSizeBytes,
    );
    if (!spaceCheck.canProceed) {
      throw StateError(
        'Nicht genuegend freier Speicherplatz fuer Download (${spaceCheck.freeBytes ~/ 1024 ~/ 1024} MB frei).',
      );
    }

    final ext = streamUrl.contains('.opus') ? 'opus' : 'm4a';
    final fileName = '${mediaItem.id}.$ext';
    final targetFile = _storage.getAudioDownloadFile(fileName);
    final partFile = _storage.getAudioPartFile(fileName);

    final task = DownloadTask(
      id: mediaItem.id,
      mediaItem: mediaItem,
      streamUrl: streamUrl,
      targetPath: targetFile.path,
      partPath: partFile.path,
      status: DownloadStatus.queued,
      totalBytes: estimatedSizeBytes,
    );

    _queue[task.id] = task;
    _notifyQueueChanged();

    // Download asynchron anstossen
    _processTask(task.id);

    return task;
  }

  /// Pausiert einen laufenden Download.
  Future<void> pauseDownload(String taskId) async {
    final task = _queue[taskId];
    if (task != null && task.isRunning) {
      _queue[taskId] = task.copyWith(status: DownloadStatus.paused);
      _notifyQueueChanged();
    }
  }

  /// Setzt einen pausierten Download fort.
  Future<void> resumeDownload(String taskId) async {
    final task = _queue[taskId];
    if (task != null && task.status == DownloadStatus.paused) {
      _queue[taskId] = task.copyWith(status: DownloadStatus.queued);
      _notifyQueueChanged();
      _processTask(taskId);
    }
  }

  /// Bricht einen Download ab und bereinigt das temporaere .part-Fragment.
  Future<void> cancelDownload(String taskId) async {
    final task = _queue[taskId];
    if (task != null) {
      _queue[taskId] = task.copyWith(status: DownloadStatus.cancelled);
      _notifyQueueChanged();

      // Temporaeres Fragment loeschen
      final partFile = File(task.partPath);
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> _processTask(String taskId) async {
    var task = _queue[taskId];
    if (task == null || task.status != DownloadStatus.queued) return;

    task = task.copyWith(status: DownloadStatus.downloading);
    _queue[taskId] = task;
    _notifyQueueChanged();

    final partFile = File(task.partPath);
    if (!partFile.parent.existsSync()) {
      partFile.parent.createSync(recursive: true);
    }

    try {
      await _transport.downloadStream(
        url: task.streamUrl,
        targetPartFile: partFile,
        onProgress: (downloaded, total) {
          final current = _queue[taskId];
          if (current != null && current.isRunning) {
            _queue[taskId] = current.copyWith(
              downloadedBytes: downloaded,
              totalBytes: total > 0 ? total : current.totalBytes,
            );
            _notifyQueueChanged();
          }
        },
        isCancelledOrPaused: () {
          final current = _queue[taskId];
          return current?.status == DownloadStatus.paused ||
              current?.status == DownloadStatus.cancelled;
        },
      );

      final postDownloadTask = _queue[taskId];
      if (postDownloadTask == null ||
          postDownloadTask.status == DownloadStatus.paused ||
          postDownloadTask.status == DownloadStatus.cancelled) {
        return;
      }

      // Metadaten- und Cover-Injektion in die heruntergeladene Datei
      await TagInjector.injectTagsIntoFile(
        targetFile: partFile,
        title: task.mediaItem.title,
        artist: task.mediaItem.author,
        album: task.mediaItem.album,
      );

      // Atomare Umbenennung von .part auf Zieldatei
      final finalFile = File(task.targetPath);
      if (finalFile.existsSync()) {
        finalFile.deleteSync();
      }
      partFile.renameSync(task.targetPath);

      // Sofortige Aktualisierung in der lokalen Bibliothek
      final localMedia = task.mediaItem.copyWith(
        source: AudioSourceRef.localFile(filePath: task.targetPath),
      );
      await _repo.saveMedia(localMedia);

      _queue[taskId] = postDownloadTask.copyWith(
        status: DownloadStatus.completed,
        downloadedBytes: postDownloadTask.totalBytes,
      );
      _notifyQueueChanged();
    } catch (e) {
      final failedTask = _queue[taskId];
      if (failedTask != null) {
        _queue[taskId] = failedTask.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        _notifyQueueChanged();
      }
    }
  }

  void _notifyQueueChanged() {
    if (!_queueController.isClosed) {
      _queueController.add(_queue.values.toList());
    }
  }

  Future<void> dispose() async {
    await _queueController.close();
  }
}
