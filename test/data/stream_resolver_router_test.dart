import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/resolvers/media_stream_resolver.dart';
import 'package:nocturne/data/resolvers/stream_models.dart';
import 'package:nocturne/data/resolvers/stream_resolver_router.dart';

class MockResolver implements MediaStreamResolver {
  MockResolver({
    required this.resolverId,
    required this.resolverTier,
    this.shouldSucceed = true,
    this.simulatedError,
    this.bitrate = 128,
  });

  @override
  final String resolverId;

  @override
  final ResolverTier resolverTier;

  bool shouldSucceed;
  Object? simulatedError;
  int bitrate;
  int callCount = 0;

  @override
  Future<ResolvedStreamResult> resolveStream(
    String mediaIdOrUrl, {
    AudioQualityPreference quality = AudioQualityPreference.high,
  }) async {
    callCount++;
    if (!shouldSucceed) {
      throw simulatedError ?? Exception('Resolver $resolverId fehlgeschlagen.');
    }
    return ResolvedStreamResult(
      streamUrl: 'https://stream.example.com/$resolverId/$mediaIdOrUrl.m4a',
      mimeType: 'audio/mp4',
      bitrateKbps: bitrate,
      resolvedByTier: resolverTier,
      isAudioOnly: true,
    );
  }

  @override
  Future<MediaStreamMetadata> getMetadata(String mediaIdOrUrl) async {
    return MediaStreamMetadata(
      id: mediaIdOrUrl,
      title: 'Titel von $resolverId',
      author: 'Autor',
    );
  }

  @override
  Future<ResolverHealthStatus> healthCheck() async {
    return ResolverHealthStatus(
      isHealthy: shouldSucceed,
      latencyMs: 45,
    );
  }
}

void main() {
  group('MediaStreamResolver & Circuit-Breaker Router Tests (TICK-019)', () {
    late MockResolver tier1;
    late MockResolver tier2;
    late MockResolver tier3;
    late StreamResolverRouter router;

    setUp(() {
      tier1 = MockResolver(
        resolverId: 'tier1_innertube',
        resolverTier: ResolverTier.tier1InnerTube,
        bitrate: 160,
      );
      tier2 = MockResolver(
        resolverId: 'tier2_invidious',
        resolverTier: ResolverTier.tier2Invidious,
        bitrate: 128,
      );
      tier3 = MockResolver(
        resolverId: 'tier3_remote_config',
        resolverTier: ResolverTier.tier3RemoteConfig,
        bitrate: 96,
      );

      router = StreamResolverRouter(
        resolvers: [tier1, tier2, tier3],
      );
    });

    test('Tier 1 loest bei Erfolg direkt auf und aktualisiert Metriken',
        () async {
      final res = await router.resolveStream('media_abc');

      expect(res.resolvedByTier, ResolverTier.tier1InnerTube);
      expect(res.bitrateKbps, 160);
      expect(tier1.callCount, 1);
      expect(tier2.callCount, 0);

      final metrics = router.metrics['tier1_innertube']!;
      expect(metrics.totalRequests, 1);
      expect(metrics.successfulRequests, 1);
      expect(metrics.failedRequests, 0);
      expect(metrics.circuitState, CircuitState.closed);
    });

    test('Circuit-Breaker schaltet nach 2 Fehlversuchen auf Tier 2 um',
        () async {
      tier1.shouldSucceed = false;

      // Erster Aufruf: Tier 1 schlaegt fehl -> Fallback auf Tier 2
      final res1 = await router.resolveStream('media_1');
      expect(res1.resolvedByTier, ResolverTier.tier2Invidious);
      expect(tier1.callCount, 1);
      expect(tier2.callCount, 1);
      expect(router.getCircuitBreaker('tier1_innertube')!.state,
          CircuitState.closed);

      // Zweiter Aufruf: Tier 1 schlaegt erneut fehl -> Circuit-Breaker loest aus (OPEN)
      final res2 = await router.resolveStream('media_2');
      expect(res2.resolvedByTier, ResolverTier.tier2Invidious);
      expect(tier1.callCount, 2);
      expect(router.getCircuitBreaker('tier1_innertube')!.state,
          CircuitState.open);

      // Dritter Aufruf: Tier 1 wird uebersprungen, Anfrage geht direkt an Tier 2
      final res3 = await router.resolveStream('media_3');
      expect(res3.resolvedByTier, ResolverTier.tier2Invidious);
      expect(tier1.callCount, 2); // Tier 1 wurde nicht mehr angerufen!
      expect(tier2.callCount, 3);
    });

    test(
        'HTTP 403 (Bot-Check/Forbidden) loest Circuit-Breaker sofort auf OPEN aus',
        () async {
      tier1.shouldSucceed = false;
      tier1.simulatedError = Exception('HTTP 403 Forbidden: Bot-Check aktiv');

      // Bereits beim 1. Fehler mit 403 muss der Circuit-Breaker ausloesen
      final res = await router.resolveStream('media_403');
      expect(res.resolvedByTier, ResolverTier.tier2Invidious);

      final breaker = router.getCircuitBreaker('tier1_innertube')!;
      expect(breaker.state, CircuitState.open);

      // Naechster Aufruf umgeht Tier 1 sofort
      await router.resolveStream('media_next');
      expect(tier1.callCount, 1);
      expect(tier2.callCount, 2);
    });

    test(
        'Fallback-Kaskade schaltet bis Tier 3 durch, wenn Tier 1 und 2 fehlschlagen',
        () async {
      tier1.shouldSucceed = false;
      tier2.shouldSucceed = false;

      final res = await router.resolveStream('cascade_test');
      expect(res.resolvedByTier, ResolverTier.tier3RemoteConfig);
      expect(tier1.callCount, 1);
      expect(tier2.callCount, 1);
      expect(tier3.callCount, 1);
    });

    test('AllResolversFailedException wird geworfen, wenn alle Stufen versagen',
        () async {
      tier1.shouldSucceed = false;
      tier2.shouldSucceed = false;
      tier3.shouldSucceed = false;

      expect(
        () => router.resolveStream('broken_media'),
        throwsA(isA<AllResolversFailedException>()),
      );
    });

    test('checkAllHealth fuehrt Diagnosetests ueber alle Endpunkte aus',
        () async {
      final health = await router.checkAllHealth();
      expect(health.length, 3);
      expect(health['tier1_innertube']!.isHealthy, isTrue);
      expect(health['tier2_invidious']!.isHealthy, isTrue);
      expect(health['tier3_remote_config']!.isHealthy, isTrue);
    });
  });
}
