import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/datasources/youtube_search_service.dart';

void main() {
  group('YouTubeSearchService Tests (TICK-V2-10)', () {
    test('extractVideoId accurately parses raw ID and various YouTube URLs', () {
      expect(YouTubeSearchService.extractVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        YouTubeSearchService.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeSearchService.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeSearchService.extractVideoId('https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=42s'),
        'dQw4w9WgXcQ',
      );
      expect(YouTubeSearchService.extractVideoId('invalid string'), isNull);
      expect(YouTubeSearchService.extractVideoId(''), isNull);
    });

    test('search returns direct result for URL input without network latency', () async {
      final service = YouTubeSearchService();
      final results = await service.search('https://youtu.be/dQw4w9WgXcQ');

      expect(results.length, 1);
      expect(results.first.videoId, 'dQw4w9WgXcQ');
      expect(results.first.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('search handles empty input gracefully', () async {
      final service = YouTubeSearchService();
      final results = await service.search('   ');
      expect(results, isEmpty);
    });
  });
}
