import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/resolvers/audio_stream_selector.dart';

void main() {
  group('Audio-Only Stream Optimierung Tests (TICK-023)', () {
    const selector = AudioOnlyStreamSelector();

    test('Video-Streams werden vollstaendig herausgefiltert', () {
      final formats = [
        {
          'mimeType': 'video/mp4; codecs="avc1.640028"',
          'bitrate': 3500000,
          'url': 'https://video.example.com/1080p.mp4',
        },
        {
          'mimeType': 'video/webm; codecs="vp9"',
          'bitrate': 2000000,
          'url': 'https://video.example.com/720p.webm',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': 'https://audio.example.com/128k.m4a',
        },
      ];

      final candidate = selector.selectBestAudioStream(formats);

      expect(candidate, isNotNull);
      expect(candidate!.mimeType.startsWith('video/'), isFalse);
      expect(candidate.mimeType.startsWith('audio/'), isTrue);
      expect(candidate.bitrateKbps, 128);
      expect(candidate.container, 'm4a');
    });

    test('Waehlt den qualitativ besten Audio-Container (Opus 160k oder M4A 128k)', () {
      final formats = [
        {
          'mimeType': 'audio/webm; codecs="opus"',
          'bitrate': 160000,
          'url': 'https://audio.example.com/160k.opus',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': 'https://audio.example.com/128k.m4a',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 48000,
          'url': 'https://audio.example.com/48k.m4a',
        },
      ];

      // Standardmaessig wird Opus 160k fuer beste Sprachwiedergabe gewaehlt
      final best = selector.selectBestAudioStream(formats, preferOpus: true);
      expect(best, isNotNull);
      expect(best!.container, 'opus');
      expect(best.bitrateKbps, 160);

      // Falls Opus nicht praeferiert wird, gewinnt M4A 128k
      final bestM4a = selector.selectBestAudioStream(formats, preferOpus: false);
      expect(bestM4a, isNotNull);
      expect(bestM4a!.container, 'm4a');
      expect(bestM4a.bitrateKbps, 128);
    });

    test('Reduziert Netzwerkdatenverbrauch um mindestens 85% gegenueber 1080p Video', () {
      // 160 kbps Audio vs. 3500 kbps (1080p Video)
      final savings160 = selector.calculateSavings(160, referenceVideoBitrateKbps: 3500);
      expect(savings160.meets85PercentTarget, isTrue);
      expect(savings160.savingsPercentage, greaterThanOrEqualTo(95.0));
      expect(savings160.megabytesPerHourAudio, closeTo(70.3, 1.0));
      expect(savings160.megabytesPerHourVideo, closeTo(1536.8, 5.0));

      // 128 kbps Audio vs. 2500 kbps (720p Video)
      final savings128 = selector.calculateSavings(128, referenceVideoBitrateKbps: 2500);
      expect(savings128.meets85PercentTarget, isTrue);
      expect(savings128.savingsPercentage, greaterThanOrEqualTo(94.0));
    });

    test('Puffer-Optimierung konfiguriert schnellen Start innerhalb von 800 ms', () {
      final config = selector.getOptimalBufferConfig();

      expect(config.initialBufferDurationMs, lessThanOrEqualTo(800));
      expect(config.bufferForPlaybackMs, 500);
      expect(config.minBufferDurationSec, 15);
      expect(config.maxBufferDurationSec, 60);
    });
  });
}
