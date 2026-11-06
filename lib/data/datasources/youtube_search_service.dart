import 'dart:convert';
import 'package:http/http.dart' as http;

/// Search result model for web streams.
class WebStreamSearchResult {
  final String videoId;
  final String title;
  final String channel;
  final Duration? duration;
  final String thumbnailUrl;
  final String url;

  const WebStreamSearchResult({
    required this.videoId,
    required this.title,
    required this.channel,
    this.duration,
    required this.thumbnailUrl,
    required this.url,
  });
}

/// Service for querying public web streams and parsing direct stream URLs.
class YouTubeSearchService {
  final http.Client _client;

  YouTubeSearchService({http.Client? client}) : _client = client ?? http.Client();

  /// Extracts the 11-character video ID from a URL or raw ID string.
  static String? extractVideoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Direct 11-char ID
    final idRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (idRegex.hasMatch(trimmed)) return trimmed;

    // youtu.be/<id>
    final youtuBeRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
    final matchShort = youtuBeRegex.firstMatch(trimmed);
    if (matchShort != null) return matchShort.group(1);

    // youtube.com/watch?v=<id>
    final ytRegex = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})');
    final matchStandard = ytRegex.firstMatch(trimmed);
    if (matchStandard != null) return matchStandard.group(1);

    return null;
  }

  /// Searches for matching web streams by query or direct URL.
  Future<List<WebStreamSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Check if query is a direct video URL or ID
    final directId = extractVideoId(trimmed);
    if (directId != null) {
      return [
        WebStreamSearchResult(
          videoId: directId,
          title: 'Web Stream ($directId)',
          channel: 'Direct Stream',
          thumbnailUrl: 'https://img.youtube.com/vi/$directId/hqdefault.jpg',
          url: 'https://www.youtube.com/watch?v=$directId',
        ),
      ];
    }

    // Federated Invidious public search endpoint fallback
    try {
      final uri = Uri.parse('https://inv.tux.pizza/api/v1/search?q=${Uri.encodeComponent(trimmed)}&type=video');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.take(15).map((item) {
          final id = item['videoId']?.toString() ?? '';
          final title = item['title']?.toString() ?? 'Audio Stream';
          final author = item['author']?.toString() ?? 'Unknown Channel';
          final lengthSec = (item['lengthSeconds'] as num?)?.toInt() ?? 0;
          return WebStreamSearchResult(
            videoId: id,
            title: title,
            channel: author,
            duration: Duration(seconds: lengthSec),
            thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
            url: 'https://www.youtube.com/watch?v=$id',
          );
        }).toList();
      }
    } catch (_) {
      // In offline or firewalled environments, fallback gracefully
    }

    // Fallback: Return structured search item for user query
    return [
      WebStreamSearchResult(
        videoId: 'search_${trimmed.hashCode.abs()}',
        title: trimmed,
        channel: 'Web Audio Stream',
        thumbnailUrl: 'https://img.youtube.com/vi/placeholder/hqdefault.jpg',
        url: 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(trimmed)}',
      ),
    ];
  }
}
