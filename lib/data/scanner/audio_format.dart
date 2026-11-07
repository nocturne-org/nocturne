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

  /// Determines the audio format from a raw extension (with or without leading dot).
  static AudioFormat? fromExtension(String ext) {
    final clean = ext.startsWith('.') ? ext.substring(1) : ext;
    final lower = clean.toLowerCase();
    for (final format in AudioFormat.values) {
      if (format.extension == lower) {
        return format;
      }
    }
    return null;
  }

  /// Checks whether a given file path is a supported audio format.
  static bool isSupported(String path) => fromPath(path) != null;

  /// The 6 core audio formats supported by the scanner.
  static const List<AudioFormat> coreSixFormats = [
    AudioFormat.mp3,
    AudioFormat.m4b,
    AudioFormat.m4a,
    AudioFormat.aac,
    AudioFormat.ogg,
    AudioFormat.wav,
  ];

  /// List of all supported lowercase extensions (without leading dot).
  static List<String> get supportedExtensions =>
      AudioFormat.values.map((f) => f.extension).toList();
}
