import 'audio_format.dart';

/// Unveraenderliches Transferobjekt fuer eine gescannte Audio-Datei.
class ScannedAudioFile {
  const ScannedAudioFile({
    required this.path,
    required this.name,
    required this.format,
    required this.sizeBytes,
    required this.lastModifiedEpochMs,
  });

  /// Absoluter Dateipfad auf dem Speichermedium.
  final String path;

  /// Vollstaendiger Dateiname inklusive Endung.
  final String name;

  /// Erkanntes Audioformat.
  final AudioFormat format;

  /// Dateigroesse in Bytes.
  final int sizeBytes;

  /// Zeitstempel der letzten Aenderung in Millisekunden seit Epoch.
  final int lastModifiedEpochMs;

  DateTime get lastModified =>
      DateTime.fromMillisecondsSinceEpoch(lastModifiedEpochMs);

  Map<String, dynamic> toMap() => {
        'path': path,
        'name': name,
        'format': format.name,
        'sizeBytes': sizeBytes,
        'lastModifiedEpochMs': lastModifiedEpochMs,
      };

  factory ScannedAudioFile.fromMap(Map<String, dynamic> map) {
    return ScannedAudioFile(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
      format: AudioFormat.values.firstWhere(
        (f) => f.name == map['format'],
        orElse: () => AudioFormat.mp3,
      ),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      lastModifiedEpochMs: (map['lastModifiedEpochMs'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedAudioFile &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          sizeBytes == other.sizeBytes &&
          lastModifiedEpochMs == other.lastModifiedEpochMs;

  @override
  int get hashCode => Object.hash(path, sizeBytes, lastModifiedEpochMs);

  @override
  String toString() =>
      'ScannedAudioFile($name, ${format.extension}, size: $sizeBytes)';
}
