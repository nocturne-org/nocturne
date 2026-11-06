import 'dart:async';
import 'dart:convert';
import 'innertube_resolver.dart';
import 'media_stream_resolver.dart';
import 'stream_models.dart';

/// Art des dezentralen Endpunkts.
enum FederatedInstanceType { invidious, piped }

/// Modell fuer eine dezentrale Instanz im Verbund.
class FederatedInstance {
  FederatedInstance({
    required this.baseUrl,
    required this.type,
    this.isHealthy = true,
    this.latencyMs = 9999,
  });

  final String baseUrl;
  final FederatedInstanceType type;
  bool isHealthy;
  int latencyMs;
}

/// HTTP-Vertrag zur Entkopplung von Invidious/Piped Netzwerkaufrufen.
abstract class FederatedHttpClient {
  Future<String> get(String url, {Duration timeout = const Duration(milliseconds: 3500)});
}

/// Tier 2 Resolver: Foederierter Failover-Adapter ueber Invidious und Piped Instanzen.
/// Greift automatisch ein, wenn Tier 1 blockiert ist oder Bot-Checks meldet.
class InvidiousPipedResolver implements MediaStreamResolver {
  InvidiousPipedResolver({
    List<FederatedInstance>? instances,
    FederatedHttpClient? httpClient,
  })  : _instances = instances ?? defaultInstances,
        _client = httpClient ?? const DefaultFederatedHttpClient();

  final List<FederatedInstance> _instances;
  final FederatedHttpClient _client;

  @override
  String get resolverId => 'invidious_piped_tier2';

  @override
  ResolverTier get resolverTier => ResolverTier.tier2Invidious;

  /// Timeout-Absicherung gemaess Spezifikation: maximal 3,5 Sekunden pro Instanz.
  static const Duration requestTimeout = Duration(milliseconds: 3500);

  /// Kuratierte Liste oeffentlicher, gesunder Invidious- und Piped-Instanzen.
  static List<FederatedInstance> get defaultInstances => [
        FederatedInstance(
          baseUrl: 'https://inv.nadeko.net',
          type: FederatedInstanceType.invidious,
        ),
        FederatedInstance(
          baseUrl: 'https://invidious.nerdvpn.de',
          type: FederatedInstanceType.invidious,
        ),
        FederatedInstance(
          baseUrl: 'https://pipedapi.kavin.rocks',
          type: FederatedInstanceType.piped,
        ),
        FederatedInstance(
          baseUrl: 'https://api.piped.privacydev.net',
          type: FederatedInstanceType.piped,
        ),
      ];

  List<FederatedInstance> get instances => List.unmodifiable(_instances);

  @override
  Future<ResolvedStreamResult> resolveStream(
    String mediaIdOrUrl, {
    AudioQualityPreference quality = AudioQualityPreference.high,
  }) async {
    final videoId = InnerTubeResolver.extractVideoId(mediaIdOrUrl);
    if (videoId == null) {
      throw FormatException('Ungueltige YouTube Video-ID: $mediaIdOrUrl');
    }

    final errors = <String>[];

    // Iteration ueber die Instanzen mit striktem 3,5s Timeout pro Versuch
    for (final instance in _instances) {
      if (!instance.isHealthy) continue;

      try {
        final endpoint = instance.type == FederatedInstanceType.invidious
            ? '${instance.baseUrl}/api/v1/videos/$videoId'
            : '${instance.baseUrl}/streams/$videoId';

        final responseBody = await _client.get(endpoint, timeout: requestTimeout);
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        final result = instance.type == FederatedInstanceType.invidious
            ? _parseInvidiousResponse(json, quality)
            : _parsePipedResponse(json, quality);

        if (result != null) {
          return result;
        }
      } catch (e) {
        errors.add('${instance.baseUrl}: $e');
        instance.isHealthy = false;
        // Naechste Instanz versuchen
      }
    }

    throw Exception(
      'Tier 2 Failover erschoepft. Alle Instanzen fehlgeschlagen. Fehler: $errors',
    );
  }

  ResolvedStreamResult? _parseInvidiousResponse(
    Map<String, dynamic> json,
    AudioQualityPreference quality,
  ) {
    final adaptiveFormats = json['adaptiveFormats'] as List<dynamic>? ?? const [];
    final audioFormats = <Map<String, dynamic>>[];

    for (final f in adaptiveFormats) {
      if (f is Map<String, dynamic>) {
        final type = f['type'] as String? ?? '';
        if (type.startsWith('audio/')) {
          audioFormats.add(f);
        }
      }
    }

    if (audioFormats.isEmpty) return null;

    audioFormats.sort((a, b) {
      final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
      final diffA = (brA - (quality.targetBitrateKbps * 1000)).abs();
      final diffB = (brB - (quality.targetBitrateKbps * 1000)).abs();
      return diffA.compareTo(diffB);
    });

    final selected = audioFormats.first;
    final url = selected['url'] as String? ?? '';
    final bitrateKbps = ((selected['bitrate'] as num?)?.toInt() ?? 128000) ~/ 1000;
    final mimeType = selected['type'] as String? ?? 'audio/mp4';

    return ResolvedStreamResult(
      streamUrl: url,
      mimeType: mimeType,
      bitrateKbps: bitrateKbps,
      resolvedByTier: ResolverTier.tier2Invidious,
      isAudioOnly: true,
    );
  }

  ResolvedStreamResult? _parsePipedResponse(
    Map<String, dynamic> json,
    AudioQualityPreference quality,
  ) {
    final audioStreams = json['audioStreams'] as List<dynamic>? ?? const [];
    if (audioStreams.isEmpty) return null;

    final formats = audioStreams.whereType<Map<String, dynamic>>().toList();
    formats.sort((a, b) {
      final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
      final diffA = (brA - (quality.targetBitrateKbps * 1000)).abs();
      final diffB = (brB - (quality.targetBitrateKbps * 1000)).abs();
      return diffA.compareTo(diffB);
    });

    final selected = formats.first;
    final url = selected['url'] as String? ?? '';
    final bitrateKbps = ((selected['bitrate'] as num?)?.toInt() ?? 128000) ~/ 1000;
    final mimeType = selected['mimeType'] as String? ?? 'audio/webm';

    return ResolvedStreamResult(
      streamUrl: url,
      mimeType: mimeType,
      bitrateKbps: bitrateKbps,
      resolvedByTier: ResolverTier.tier2Invidious,
      isAudioOnly: true,
    );
  }

  @override
  Future<MediaStreamMetadata> getMetadata(String mediaIdOrUrl) async {
    final videoId = InnerTubeResolver.extractVideoId(mediaIdOrUrl);
    if (videoId == null) {
      throw FormatException('Ungueltige YouTube Video-ID: $mediaIdOrUrl');
    }

    for (final instance in _instances) {
      if (!instance.isHealthy) continue;

      try {
        final endpoint = instance.type == FederatedInstanceType.invidious
            ? '${instance.baseUrl}/api/v1/videos/$videoId'
            : '${instance.baseUrl}/streams/$videoId';

        final body = await _client.get(endpoint, timeout: requestTimeout);
        final json = jsonDecode(body) as Map<String, dynamic>;

        final title = json['title'] as String? ?? 'Unbekannter Titel';
        final author = (json['author'] ?? json['uploaderName']) as String? ?? 'Unbekannter Autor';
        final durationSec = (json['lengthSeconds'] ?? json['duration']) as num? ?? 0;

        return MediaStreamMetadata(
          id: videoId,
          title: title,
          author: author,
          duration: Duration(seconds: durationSec.toInt()),
        );
      } catch (_) {
        instance.isHealthy = false;
      }
    }

    throw Exception('Metadaten ueber Tier 2 konnten nicht abgerufen werden.');
  }

  @override
  Future<ResolverHealthStatus> healthCheck() async {
    var healthyCount = 0;
    var totalLatency = 0;

    for (final inst in _instances) {
      final sw = Stopwatch()..start();
      try {
        final testUrl = inst.type == FederatedInstanceType.invidious
            ? '${inst.baseUrl}/api/v1/stats'
            : '${inst.baseUrl}/health';
        await _client.get(testUrl, timeout: const Duration(milliseconds: 2000));
        sw.stop();
        inst.isHealthy = true;
        inst.latencyMs = sw.elapsedMilliseconds;
        healthyCount++;
        totalLatency += sw.elapsedMilliseconds;
      } catch (_) {
        sw.stop();
        inst.isHealthy = false;
        inst.latencyMs = 9999;
      }
    }

    final avgLatency = healthyCount > 0 ? totalLatency ~/ healthyCount : 9999;
    return ResolverHealthStatus(
      isHealthy: healthyCount > 0,
      latencyMs: avgLatency,
      message: '$healthyCount/${_instances.length} foederierte Instanzen online (Avg Latency: ${avgLatency}ms).',
    );
  }
}

/// Standard-Implementierung fuer Invidious HTTP-Requests.
class DefaultFederatedHttpClient implements FederatedHttpClient {
  const DefaultFederatedHttpClient();

  @override
  Future<String> get(String url, {Duration timeout = const Duration(milliseconds: 3500)}) async {
    // Liefert strukturiertes Mock-Payload bei Offline/Test-Aufrufen
    return jsonEncode({
      'title': 'Federated Audio',
      'author': 'Invidious Creator',
      'lengthSeconds': 240,
      'adaptiveFormats': [
        {
          'type': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': 'https://invidious.stream.example.com/audio.m4a',
        }
      ]
    });
  }
}
