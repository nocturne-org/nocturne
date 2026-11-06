/// Priorisierungsstufen der Stream-Resolver.
enum ResolverTier {
  /// Tier 1: Lokale In-App Extraktion (z. B. InnerTube).
  tier1InnerTube,

  /// Tier 2: Foederierte Proxy-APIs (z. B. Invidious, Piped).
  tier2Invidious,

  /// Tier 3: Dynamische Remote-Config Regel-Engine.
  tier3RemoteConfig,
}

/// Zustaende des Circuit-Breakers.
enum CircuitState {
  /// Normalbetrieb: Anfragen werden an den Resolver gesendet.
  closed,

  /// Schutzmodus: Endpunkt blockiert nach Fehlern (Anfragen werden sofort umgeleitet).
  open,

  /// Testmodus: Nach Abklingzeit wird eine einzelne Probe-Anfrage getestet.
  halfOpen,
}

/// Bevorzugte Audioqualitaet.
enum AudioQualityPreference {
  low(64),
  medium(128),
  high(160);

  const AudioQualityPreference(this.targetBitrateKbps);
  final int targetBitrateKbps;
}

/// Ergebnis einer erfolgreichen Stream-Aufloesung.
class ResolvedStreamResult {
  const ResolvedStreamResult({
    required this.streamUrl,
    required this.mimeType,
    required this.bitrateKbps,
    required this.resolvedByTier,
    this.duration,
    this.isAudioOnly = true,
    this.headers = const {},
  });

  /// Direkte HTTP-Streaming-URL.
  final String streamUrl;

  /// MIME-Type des Audio- oder Video-Streams (z. B. audio/mp4, audio/webm).
  final String mimeType;

  /// Bitrate in Kilobit pro Sekunde.
  final int bitrateKbps;

  /// Stufe des Resolvers, der den Stream geliefert hat.
  final ResolverTier resolvedByTier;

  /// Gesamtdauer des Mediums (falls bekannt).
  final Duration? duration;

  /// Kennzeichnung als reiner Audiostream (85-90% Bandbreitenersparnis).
  final bool isAudioOnly;

  /// Spezifische HTTP-Header (z. B. Referer, User-Agent).
  final Map<String, String> headers;

  @override
  String toString() =>
      'ResolvedStreamResult(tier: $resolvedByTier, bitrate: ${bitrateKbps}k, audioOnly: $isAudioOnly)';
}

/// Grundlegende Metadaten eines Remote-Streams.
class MediaStreamMetadata {
  const MediaStreamMetadata({
    required this.id,
    required this.title,
    required this.author,
    this.duration = Duration.zero,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;
}

/// Gesundheitsstatus eines Resolvers.
class ResolverHealthStatus {
  const ResolverHealthStatus({
    required this.isHealthy,
    required this.latencyMs,
    this.message,
  });

  final bool isHealthy;
  final int latencyMs;
  final String? message;
}

/// Statistische Metriken und Latenzdaten eines Resolver-Endpunkts.
class ResolverMetrics {
  ResolverMetrics({
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.consecutiveFailures = 0,
    this.totalLatencyMs = 0,
    this.lastLatencyMs = 0,
    this.circuitState = CircuitState.closed,
    this.lastFailureReason,
    this.lastFailureTime,
  });

  int totalRequests;
  int successfulRequests;
  int failedRequests;
  int consecutiveFailures;
  int totalLatencyMs;
  int lastLatencyMs;
  CircuitState circuitState;
  String? lastFailureReason;
  DateTime? lastFailureTime;

  double get averageLatencyMs =>
      successfulRequests > 0 ? totalLatencyMs / successfulRequests : 0.0;

  double get successRate =>
      totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0.0;

  @override
  String toString() =>
      'ResolverMetrics(requests: $totalRequests, success: ${successRate.toStringAsFixed(1)}%, avgLatency: ${averageLatencyMs.toStringAsFixed(0)}ms, state: $circuitState)';
}
