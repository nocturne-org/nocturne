import '../../domain/models/media_item.dart';

/// Zustaende eines Download-Auftrags.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Modell fuer einen einzelnen Download-Auftrag in der Offline-Warteschlange.
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.mediaItem,
    required this.streamUrl,
    required this.targetPath,
    required this.partPath,
    this.status = DownloadStatus.queued,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  /// Eindeutige Kennung des Auftrags.
  final String id;

  /// Zugeordnetes Medien-Domaenenmodell.
  final MediaItem mediaItem;

  /// HTTP-Stream-URL der Audioquelle.
  final String streamUrl;

  /// Finaler Zielpfad in der internen Sandbox.
  final String targetPath;

  /// Temporaerer Pfad waehrend des Downloads (.part-Datei).
  final String partPath;

  /// Aktueller Zustand in der Warteschlange.
  final DownloadStatus status;

  /// Bisher uebertragene Bytes.
  final int downloadedBytes;

  /// Gesamtgroesse der Datei in Bytes (falls bekannt).
  final int totalBytes;

  /// Fehlermeldung bei Status 'failed'.
  final String? errorMessage;

  /// Relativer Fortschritt (0.0 bis 1.0).
  double get progressFraction {
    if (totalBytes <= 0) return 0.0;
    final f = downloadedBytes / totalBytes;
    return f.clamp(0.0, 1.0);
  }

  /// Ob der Download gerade laeuft.
  bool get isRunning => status == DownloadStatus.downloading;

  /// Ob der Download abgeschlossen ist.
  bool get isCompleted => status == DownloadStatus.completed;

  DownloadTask copyWith({
    String? id,
    MediaItem? mediaItem,
    String? streamUrl,
    String? targetPath,
    String? partPath,
    DownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      mediaItem: mediaItem ?? this.mediaItem,
      streamUrl: streamUrl ?? this.streamUrl,
      targetPath: targetPath ?? this.targetPath,
      partPath: partPath ?? this.partPath,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'DownloadTask($id, ${mediaItem.title}, status: $status, ${(progressFraction * 100).toStringAsFixed(1)}%)';
}
