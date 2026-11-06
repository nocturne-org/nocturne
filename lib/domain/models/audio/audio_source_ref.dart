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
  const factory AudioSourceRef.file(String path, {String? title, String? artist}) =
      _AudioSourceRefFile;

  /// Alias fuer lokale Datei.
  const factory AudioSourceRef.localFile(String path, {String? title, String? artist}) =
      _AudioSourceRefFile;

  /// Erzeugt eine Referenz fuer ein Android SAF Uri (content://).
  const factory AudioSourceRef.saf(String contentUri, {String? title, String? artist}) =
      _AudioSourceRefSaf;

  /// Erzeugt eine Referenz fuer einen Netzwerk-Stream.
  const factory AudioSourceRef.network(String streamUrl, {String? title, String? artist}) =
      _AudioSourceRefNetwork;

  /// Alias fuer Streaming-URL.
  const factory AudioSourceRef.streamingUrl(String streamUrl, {String? title, String? artist}) =
      _AudioSourceRefNetwork;

  /// Alias fuer YouTube-Streams.
  const factory AudioSourceRef.youTube(String streamUrl, {String? title, String? artist}) =
      _AudioSourceRefNetwork;

  /// Erzeugt eine modifizierte Kopie dieses [AudioSourceRef].
  AudioSourceRef copyWith({
    String? uri,
    AudioSourceType? type,
    String? title,
    String? artist,
  }) {
    return AudioSourceRef(
      uri: uri ?? this.uri,
      type: type ?? this.type,
      title: title ?? this.title,
      artist: artist ?? this.artist,
    );
  }

  /// Serialisiert die Audio-Referenz in eine Map.
  Map<String, dynamic> toMap() {
    return {
      'uri': uri,
      'type': type.name,
      'title': title,
      'artist': artist,
    };
  }

  /// Deserialisiert ein [AudioSourceRef] aus einer Map.
  factory AudioSourceRef.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? AudioSourceType.file.name;
    final type = AudioSourceType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => AudioSourceType.file,
    );

    return AudioSourceRef(
      uri: map['uri'] as String? ?? '',
      type: type,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSourceRef &&
          uri == other.uri &&
          type == other.type &&
          title == other.title &&
          artist == other.artist;

  @override
  int get hashCode => Object.hash(uri, type, title, artist);

  @override
  String toString() => 'AudioSourceRef(uri: $uri, type: $type, title: $title)';
}

class _AudioSourceRefFile extends AudioSourceRef {
  const _AudioSourceRefFile(String path, {super.title, super.artist})
      : super(uri: path, type: AudioSourceType.file);
}

class _AudioSourceRefSaf extends AudioSourceRef {
  const _AudioSourceRefSaf(String contentUri, {super.title, super.artist})
      : super(uri: contentUri, type: AudioSourceType.safContentUri);
}

class _AudioSourceRefNetwork extends AudioSourceRef {
  const _AudioSourceRefNetwork(String streamUrl, {super.title, super.artist})
      : super(uri: streamUrl, type: AudioSourceType.networkStream);
}
