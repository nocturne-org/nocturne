/// Repraesentiert dynamische Laufzeit-Konfigurationen fuer Resolver und Client-Parameter.
class RemoteAppConfig {
  const RemoteAppConfig({
    required this.version,
    required this.userAgent,
    required this.innertubeClientVersion,
    required this.invidiousInstances,
    required this.pipedInstances,
    required this.lastUpdated,
    this.sha256Hash,
  });

  /// Konfigurations-Versionsnummer (z. B. 1.2).
  final int version;

  /// Aktueller HTTP User-Agent zur Vermeidung von Drosselung.
  final String userAgent;

  /// Aktuelle YouTube InnerTube Client-Version (z. B. "2.20261101.01.00").
  final String innertubeClientVersion;

  /// Liste aktiver, kuratierter Invidious-Instanz-URLs.
  final List<String> invidiousInstances;

  /// Liste aktiver Piped-Instanz-URLs.
  final List<String> pipedInstances;

  /// Zeitstempel der Konfigurationserstellung.
  final DateTime lastUpdated;

  /// Optionaler SHA-256 Hash zur Integritaetspruefung.
  final String? sha256Hash;

  /// Eingebaute Standard-Konfiguration als Offline-Sicherheitsnetz.
  static final RemoteAppConfig defaults = RemoteAppConfig(
    version: 1,
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    innertubeClientVersion: '2.20261101.01.00',
    invidiousInstances: const [
      'https://inv.nadeko.net',
      'https://invidious.nerdvpn.de',
    ],
    pipedInstances: const [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.privacydev.net',
    ],
    lastUpdated: DateTime(2026, 11, 1),
  );

  Map<String, dynamic> toMap() => {
        'version': version,
        'userAgent': userAgent,
        'innertubeClientVersion': innertubeClientVersion,
        'invidiousInstances': invidiousInstances,
        'pipedInstances': pipedInstances,
        'lastUpdated': lastUpdated.toIso8601String(),
        if (sha256Hash != null) 'sha256Hash': sha256Hash,
      };

  factory RemoteAppConfig.fromMap(Map<String, dynamic> map, {String? calculatedHash}) {
    return RemoteAppConfig(
      version: (map['version'] as num?)?.toInt() ?? 1,
      userAgent: map['userAgent'] as String? ?? defaults.userAgent,
      innertubeClientVersion:
          map['innertubeClientVersion'] as String? ?? defaults.innertubeClientVersion,
      invidiousInstances: (map['invidiousInstances'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.invidiousInstances,
      pipedInstances: (map['pipedInstances'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.pipedInstances,
      lastUpdated: DateTime.tryParse(map['lastUpdated'] as String? ?? '') ??
          DateTime.now(),
      sha256Hash: map['sha256Hash'] as String? ?? calculatedHash,
    );
  }

  @override
  String toString() =>
      'RemoteAppConfig(v$version, innerTube: $innertubeClientVersion, invidious: ${invidiousInstances.length}, piped: ${pipedInstances.length})';
}
