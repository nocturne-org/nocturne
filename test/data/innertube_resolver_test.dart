import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/resolvers/innertube_resolver.dart';
import 'package:nocturne/data/resolvers/stream_models.dart';

class TestMockInnerTubeClient implements InnerTubeClientContract {
  Map<String, dynamic>? mockResponse;
  bool shouldThrowBotCheck = false;

  @override
  Future<Map<String, dynamic>> fetchPlayerResponse(String videoId) async {
    if (shouldThrowBotCheck) {
      return {
        'playabilityStatus': {
          'status': 'LOGIN_REQUIRED',
          'reason': 'Sign in to confirm you are not a bot',
        }
      };
    }

    return mockResponse ??
        {
          'playabilityStatus': {'status': 'OK'},
          'videoDetails': {
            'videoId': videoId,
            'title': 'Test Bedtime Ambience',
            'author': 'Sleep Channel',
            'lengthSeconds': '1800',
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://img.youtube.com/vi/$videoId/maxres.jpg'}
              ]
            }
          },
          'streamingData': {
            'adaptiveFormats': [
              {
                'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
                'bitrate': 160000,
                'url': 'https://rr.googlevideo.com/videoplayback?id=$videoId&n=NToken1234',
              },
              {
                'mimeType': 'audio/webm; codecs="opus"',
                'bitrate': 128000,
                'url': 'https://rr.googlevideo.com/videoplayback?id=$videoId&n=NToken5678',
              },
              {
                'mimeType': 'video/mp4; codecs="avc1.4d401f"',
                'bitrate': 1500000,
                'url': 'https://rr.googlevideo.com/videoplayback?id=$videoId&video=true',
              }
            ]
          }
        };
  }
}

void main() {
  group('InnerTube Tier 1 Resolver Tests (TICK-020)', () {
    late TestMockInnerTubeClient mockClient;
    late InnerTubeResolver resolver;

    setUp(() {
      mockClient = TestMockInnerTubeClient();
      resolver = InnerTubeResolver(client: mockClient);
    });

    test('extractVideoId extrahiert IDs aus allen URL-Varianten und Kurz-Links', () {
      expect(
        InnerTubeResolver.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        InnerTubeResolver.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        InnerTubeResolver.extractVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        InnerTubeResolver.extractVideoId('dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        InnerTubeResolver.extractVideoId('https://example.com/invalid_url'),
        isNull,
      );
    });

    test('decipherNSig transformiert n-Token gegen Bandbreitendrosselung', () {
      const original = 'abcdefgh';
      final transformed = InnerTubeResolver.decipherNSig(original);

      expect(transformed.isNotEmpty, isTrue);
      expect(transformed, isNot(original));
    });

    test('resolveStream waehlt bevorzugte Audio-Bitrate und transformiert n-Parameter', () async {
      final res = await resolver.resolveStream(
        'https://youtu.be/dQw4w9WgXcQ',
        quality: AudioQualityPreference.high,
      );

      expect(res.resolvedByTier, ResolverTier.tier1InnerTube);
      expect(res.isAudioOnly, isTrue);
      expect(res.bitrateKbps, 160);
      expect(res.mimeType, contains('audio/mp4'));
      expect(res.streamUrl, contains('rr.googlevideo.com'));
      // Der n-Parameter wurde transformiert
      expect(res.streamUrl, contains('n='));
    });

    test('getMetadata extrahiert Titel, Autor, Dauer und Thumbnail', () async {
      final meta = await resolver.getMetadata('dQw4w9WgXcQ');

      expect(meta.id, 'dQw4w9WgXcQ');
      expect(meta.title, 'Test Bedtime Ambience');
      expect(meta.author, 'Sleep Channel');
      expect(meta.duration.inMinutes, 30);
      expect(meta.thumbnailUrl, contains('maxres.jpg'));
    });

    test('Bot-Check / Login-Required wirft HTTP 403 zur Circuit-Breaker Ausloesung', () async {
      mockClient.shouldThrowBotCheck = true;

      expect(
        () => resolver.resolveStream('dQw4w9WgXcQ'),
        throwsA(predicate((e) => e.toString().contains('403'))),
      );
    });
  });
}
