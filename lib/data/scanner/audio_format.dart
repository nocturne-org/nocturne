/// Unterstuetzte Audioformate fuer den lokalen Bibliotheks-Scan.
enum AudioFormat {
  mp3('mp3', 'audio/mpeg'),
  m4b('m4b', 'audio/mp4'),
  m4a('m4a', 'audio/mp4'),
  flac('flac', 'audio/flac'),
  opus('opus', 'audio/ogg');

  const AudioFormat(this.extension, this.mimeType);

  /// Dateiendung in Kleinbuchstaben (ohne fuehrenden Punkt).
  final String extension;

  /// MIME-Type des Audioformats.
  final String mimeType;

  /// Ermittelt das Audioformat anhand der Dateiendung oder des Dateipfads.
  static AudioFormat? fromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return null;
    }
    final ext = path.substring(dotIndex + 1).toLowerCase();
    for (final format in AudioFormat.values) {
      if (format.extension == ext) {
        return format;
      }
    }
    return null;
  }

  /// Prueft, ob ein Dateipfad eine unterstuetzte Audioendung besitzt.
  static bool isSupported(String path) => fromPath(path) != null;
}
