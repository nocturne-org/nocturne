import 'circuit_breaker.dart';
import 'media_stream_resolver.dart';
import 'stream_models.dart';

/// Ausnahme, falls saemtliche Resolver-Stufen in der Fallback-Kaskade fehlschlagen.
class AllResolversFailedException implements Exception {
  const AllResolversFailedException({
    required this.mediaIdOrUrl,
    required this.diagnosticErrors,
  });

  final String mediaIdOrUrl;
  final Map<String, String> diagnosticErrors;

  @override
  String toString() {
    return 'AllResolversFailedException: Alle Resolver fuer "$mediaIdOrUrl" fehlgeschlagen. Diagnose: $diagnosticErrors';
  }
}

/// Intelligenter Router fuer Pluggable Stream-Resolvers mit Circuit-Breaker-Pattern
/// und 3-Stufen-Failover-Kaskade (Tier 1 -> Tier 2 -> Tier 3).
class StreamResolverRouter {
  StreamResolverRouter({
    required List<MediaStreamResolver> resolvers,
    Map<String, CircuitBreaker>? circuitBreakers,
  }) : _resolvers = resolvers {
    // Sortierung nach Tier-Prioritaet
    _resolvers
        .sort((a, b) => a.resolverTier.index.compareTo(b.resolverTier.index));

    for (final r in _resolvers) {
      _circuitBreakers[r.resolverId] =
          circuitBreakers?[r.resolverId] ?? CircuitBreaker();
      _metrics[r.resolverId] = ResolverMetrics();
    }
  }

  final List<MediaStreamResolver> _resolvers;
  final Map<String, CircuitBreaker> _circuitBreakers = {};
  final Map<String, ResolverMetrics> _metrics = {};

  /// Liefert die aktuellen Metriken aller registrierten Resolver.
  Map<String, ResolverMetrics> get metrics => Map.unmodifiable(_metrics);

  /// Liefert den Circuit-Breaker fuer einen bestimmten Resolver.
  CircuitBreaker? getCircuitBreaker(String resolverId) =>
      _circuitBreakers[resolverId];

  /// Loest einen Audiostream ueber die 3-Stufen-Kaskade auf.
  Future<ResolvedStreamResult> resolveStream(
    String mediaIdOrUrl, {
    AudioQualityPreference quality = AudioQualityPreference.high,
  }) async {
    final diagnosticErrors = <String, String>{};

    for (final resolver in _resolvers) {
      final id = resolver.resolverId;
      final breaker = _circuitBreakers[id]!;
      final metric = _metrics[id]!;

      // Circuit-Breaker Status aktualisieren
      metric.circuitState = breaker.state;

      if (!breaker.canAttempt) {
        diagnosticErrors[id] =
            'Uebersprungen: Circuit-Breaker ist OPEN (nach ${breaker.consecutiveFailures} Fehlern).';
        continue;
      }

      metric.totalRequests++;
      final stopwatch = Stopwatch()..start();

      try {
        final result =
            await resolver.resolveStream(mediaIdOrUrl, quality: quality);
        stopwatch.stop();

        final latency = stopwatch.elapsedMilliseconds;
        metric.successfulRequests++;
        metric.consecutiveFailures = 0;
        metric.totalLatencyMs += latency;
        metric.lastLatencyMs = latency;
        metric.circuitState = CircuitState.closed;

        breaker.recordSuccess();

        return result;
      } catch (e) {
        stopwatch.stop();
        final latency = stopwatch.elapsedMilliseconds;

        metric.failedRequests++;
        metric.consecutiveFailures++;
        metric.lastLatencyMs = latency;
        metric.lastFailureReason = e.toString();
        metric.lastFailureTime = DateTime.now();

        breaker.recordFailure(e);
        metric.circuitState = breaker.state;

        diagnosticErrors[id] = 'Fehler nach ${latency}ms: $e';
      }
    }

    throw AllResolversFailedException(
      mediaIdOrUrl: mediaIdOrUrl,
      diagnosticErrors: diagnosticErrors,
    );
  }

  /// Fragt den Gesundheitsstatus aller Resolver-Endpunkte ab.
  Future<Map<String, ResolverHealthStatus>> checkAllHealth() async {
    final results = <String, ResolverHealthStatus>{};
    for (final r in _resolvers) {
      try {
        results[r.resolverId] = await r.healthCheck();
      } catch (e) {
        results[r.resolverId] = ResolverHealthStatus(
          isHealthy: false,
          latencyMs: 0,
          message: e.toString(),
        );
      }
    }
    return results;
  }
}
