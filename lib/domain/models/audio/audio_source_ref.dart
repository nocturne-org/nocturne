/// Typ der Audioquelle zur typsicheren Kapselung im Domain-Layer.
enum AudioSourceType {
  /// Lokale Datei im Dateisystem (z. B. Sandbox).
  file,

  /// Android Storage Access Framework URI (content://).
  safContentUri,

  /// Remote Web-Stream (HTTP/HTTPS).
  networkStream,
}

/// Unveraenderliches Value-Object fuer Audio-Referenzen im Domain-Layer.
/// Verhindert Primitive-Obsession und kapselt Quelltyp, URI und Metadaten.
class AudioSourceRef {
  /// Eindeutiger URI-String oder Pfad der Audioquelle.
  final String uri;

  /// Typ der Audioquelle.
  final AudioSourceType type;

  /// Optionaler Anzeigetitel.
  final String? title;

  /// Optionaler Name des Autors oder Sprechers.
  final String? artist;

  const AudioSourceRef({
    required this.uri,
    required this.type,
    this.title,
    this.artist,
  });

  /// Erzeugt eine Referenz fuer eine lokale Datei.
  factory AudioSourceRef.file(String path, {String? title, String? artist}) {
    return AudioSourceRef(
      uri: path,
      type: AudioSourceType.file,
      title: title,
      artist: artist,
    );
  }

  /// Erzeugt eine Referenz fuer ein Android SAF Uri (content://).
  factory AudioSourceRef.saf(String contentUri, {String? title, String? artist}) {
    return AudioSourceRef(
      uri: contentUri,
      type: AudioSourceType.safContentUri,
      title: title,
      artist: artist,
    );
  }

  /// Erzeugt eine Referenz fuer einen Netzwerk-Stream.
  factory AudioSourceRef.network(String streamUrl, {String? title, String? artist}) {
    return AudioSourceRef(
      uri: streamUrl,
      type: AudioSourceType.networkStream,
      title: title,
      artist: artist,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSourceRef &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          type == other.type &&
          title == other.title &&
          artist == other.artist;

  @override
  int get hashCode => Object.hash(uri, type, title, artist);

  @override
  String toString() => 'AudioSourceRef(uri: $uri, type: $type, title: $title)';
}
