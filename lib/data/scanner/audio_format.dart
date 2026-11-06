/// Supported audio formats for local file and folder imports.
enum AudioFormat {
  mp3('mp3', 'audio/mpeg'),
  m4b('m4b', 'audio/mp4'),
  m4a('m4a', 'audio/mp4'),
  aac('aac', 'audio/aac'),
  flac('flac', 'audio/flac'),
  opus('opus', 'audio/ogg'),
  ogg('ogg', 'audio/ogg'),
  wav('wav', 'audio/wav');

  const AudioFormat(this.extension, this.mimeType);

  /// Lowercase file extension (without leading dot).
  final String extension;

  /// MIME type of the audio format.
  final String mimeType;

  /// Determines the audio format from the file path extension.
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

  /// Checks whether a given file path is a supported audio format.
  static bool isSupported(String path) => fromPath(path) != null;
}
