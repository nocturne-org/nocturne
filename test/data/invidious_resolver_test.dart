import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/resolvers/invidious_resolver.dart';
import 'package:nocturne/data/resolvers/stream_models.dart';

class TestMockFederatedClient implements FederatedHttpClient {
  final Map<String, String> responses = {};
  final Set<String> timeoutEndpoints = {};
  final Set<String> failingEndpoints = {};
  int callCount = 0;

  @override
  Future<String> get(String url,
      {Duration timeout = const Duration(milliseconds: 3500)}) async {
    callCount++;
    if (timeoutEndpoints.contains(url)) {
      throw TimeoutException('Zeitueberschreitung nach 3.5s');
    }
    if (failingEndpoints.contains(url)) {
      throw Exception('HTTP 502 Bad Gateway');
    }
    return responses[url] ??
        jsonEncode({
          'title': 'Default Audio',
          'author': 'Default Artist',
          'lengthSeconds': 300,
          'adaptiveFormats': [
            {
              'type': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 128000,
              'url': 'https://stream.fallback.org/audio.m4a',
            }
          ]
        });
  }
}

void main() {
  group('Tier 2: Invidious & Piped Resolver Tests (TICK-021)', () {
    late TestMockFederatedClient mockClient;
    late InvidiousPipedResolver resolver;

    setUp(() {
      mockClient = TestMockFederatedClient();
      resolver = InvidiousPipedResolver(httpClient: mockClient);
    });

    test('Kuratierte Liste enthaelt gesunde Invidious- und Piped-Instanzen',
        () {
      final instances = InvidiousPipedResolver.defaultInstances;
      expect(instances.length, greaterThanOrEqualTo(4));
      expect(instances.any((i) => i.type == FederatedInstanceType.invidious),
          isTrue);
      expect(
          instances.any((i) => i.type == FederatedInstanceType.piped), isTrue);
    });

    test(
        'Invidious JSON Antwort wird nahtlos in ResolvedStreamResult konvertiert',
        () async {
      final invidiousJson = jsonEncode({
        'title': 'Nocturne Bedtime Story',
        'author': 'Audio Creator',
        'adaptiveFormats': [
          {
            'type': 'audio/mp4; codecs="mp4a.40.2"',
            'bitrate': 160000,
            'url': 'https://invidious.nadeko.net/stream/160k.m4a',
          },
          {
            'type': 'audio/webm; codecs="opus"',
            'bitrate': 128000,
            'url': 'https://invidious.nadeko.net/stream/128k.opus',
          }
        ]
      });

      mockClient.responses['https://inv.nadeko.net/api/v1/videos/dQw4w9WgXcQ'] =
          invidiousJson;

      final res = await resolver.resolveStream(
        'https://youtu.be/dQw4w9WgXcQ',
        quality: AudioQualityPreference.high,
      );

      expect(res.resolvedByTier, ResolverTier.tier2Invidious);
      expect(res.isAudioOnly, isTrue);
      expect(res.bitrateKbps, 160);
      expect(res.streamUrl, contains('160k.m4a'));
    });

    test('Piped JSON Antwort wird korrekt aufgeloest', () async {
      final testInstances = [
        FederatedInstance(
          baseUrl: 'https://piped.test.org',
          type: FederatedInstanceType.piped,
        ),
      ];

      final pipedJson = jsonEncode({
        'title': 'Piped Stream',
        'uploaderName': 'Piped Uploader',
        'audioStreams': [
          {
            'mimeType': 'audio/webm; codecs="opus"',
            'bitrate': 128000,
            'url': 'https://piped.stream/audio.opus',
          }
        ]
      });

      mockClient.responses['https://piped.test.org/streams/dQw4w9WgXcQ'] =
          pipedJson;

      final pipedResolver = InvidiousPipedResolver(
        instances: testInstances,
        httpClient: mockClient,
      );

      final res = await pipedResolver.resolveStream('dQw4w9WgXcQ');
      expect(res.resolvedByTier, ResolverTier.tier2Invidious);
      expect(res.bitrateKbps, 128);
      expect(res.streamUrl, 'https://piped.stream/audio.opus');
    });

    test(
        'Timeout (3.5s) loest automatischen Failover zur naechsten Instanz aus',
        () async {
      final testInstances = [
        FederatedInstance(
          baseUrl: 'https://inst1.fail.org',
          type: FederatedInstanceType.invidious,
        ),
        FederatedInstance(
          baseUrl: 'https://inst2.success.org',
          type: FederatedInstanceType.invidious,
        ),
      ];

      // Instanz 1 laeuft in einen 3.5s Timeout
      mockClient.timeoutEndpoints
          .add('https://inst1.fail.org/api/v1/videos/dQw4w9WgXcQ');

      // Instanz 2 antwortet schnell
      mockClient.responses[
          'https://inst2.success.org/api/v1/videos/dQw4w9WgXcQ'] = jsonEncode({
        'title': 'Failover Audio',
        'adaptiveFormats': [
          {
            'type': 'audio/mp4; codecs="mp4a.40.2"',
            'bitrate': 128000,
            'url': 'https://inst2.success.org/stream.m4a',
          }
        ]
      });

      final multiResolver = InvidiousPipedResolver(
        instances: testInstances,
        httpClient: mockClient,
      );

      final res = await multiResolver.resolveStream('dQw4w9WgXcQ');

      expect(res.resolvedByTier, ResolverTier.tier2Invidious);
      expect(res.streamUrl, contains('inst2.success.org'));
      // Instanz 1 wurde als ungesund markiert
      expect(testInstances[0].isHealthy, isFalse);
      expect(testInstances[1].isHealthy, isTrue);
    });

    test('healthCheck diagnostiziert Erreichbarkeit und Latenz aller Instanzen',
        () async {
      mockClient.responses['https://inv.nadeko.net/api/v1/stats'] =
          '{"status":"ok"}';
      mockClient.failingEndpoints
          .add('https://invidious.nerdvpn.de/api/v1/stats');

      final health = await resolver.healthCheck();

      expect(health.isHealthy, isTrue);
      expect(health.message, contains('foederierte Instanzen online'));
    });
  });
}
