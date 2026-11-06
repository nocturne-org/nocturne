import 'stream_models.dart';

/// Basis-Schnittstelle fuer plattformunabhaengige Media-Stream-Resolver.
/// Definiert die Extraktion von direkten Audio-Streams, Metadaten und Gesundheitspruefungen.
abstract class MediaStreamResolver {
  /// Eindeutige Kennung des Resolver-Dienstes (z. B. "innertube_primary", "invidious_proxy").
  String get resolverId;

  /// Priorisierungsstufe im Failover-Verbund.
  ResolverTier get resolverTier;

  /// Loest eine Medien-ID oder Stream-URL in einen direkten, abspielbaren Audiostream auf.
  Future<ResolvedStreamResult> resolveStream(
    String mediaIdOrUrl, {
    AudioQualityPreference quality = AudioQualityPreference.high,
  });

  /// Fragt Basis-Metadaten (Titel, Autor, Dauer, Thumbnail) ab.
  Future<MediaStreamMetadata> getMetadata(String mediaIdOrUrl);

  /// Fuehrt eine schnelle Diagnosepruefung auf Erreichbarkeit und Latenz durch.
  Future<ResolverHealthStatus> healthCheck();
}
