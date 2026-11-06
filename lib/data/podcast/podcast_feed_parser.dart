import 'dart:convert';
import 'podcast_models.dart';

/// Robuster, leichtgewichtiger Parser fuer RSS 2.0 und Apple Podcasts (iTunes XML).
class PodcastFeedParser {
  const PodcastFeedParser();

  /// Parst einen XML-String in ein strukturiertes PodcastFeed-Objekt.
  PodcastFeed parse({
    required String xmlContent,
    required String feedUrl,
  }) {
    final cleanXml = _preprocessXml(xmlContent);

    // Channel-Block isolieren
    final channelMatch =
        RegExp(r'<channel[^>]*>([\s\S]*?)<\/channel>', caseSensitive: false)
            .firstMatch(cleanXml);
    final channelContent =
        channelMatch != null ? channelMatch.group(1)! : cleanXml;

    final channelTitle =
        _extractTag(channelContent, 'title') ?? 'Unbekannter Podcast';
    final channelDescription = _extractTag(channelContent, 'description') ?? '';
    final channelLink = _extractTag(channelContent, 'link') ?? '';
    final channelAuthor = _extractTag(channelContent, 'itunes:author') ??
        _extractTag(channelContent, 'author') ??
        _extractTag(channelContent, 'managingEditor') ??
        '';
    final channelLanguage = _extractTag(channelContent, 'language') ?? 'de';

    // Channel-Coverbild
    String? channelImage =
        _extractAttribute(channelContent, 'itunes:image', 'href');
    if (channelImage == null || channelImage.isEmpty) {
      final imageBlock =
          RegExp(r'<image[^>]*>([\s\S]*?)<\/image>', caseSensitive: false)
              .firstMatch(channelContent);
      if (imageBlock != null) {
        channelImage = _extractTag(imageBlock.group(1)!, 'url');
      }
    }

    // Episoden-Items isolieren
    final itemRegex =
        RegExp(r'<item[^>]*>([\s\S]*?)<\/item>', caseSensitive: false);
    final itemMatches = itemRegex.allMatches(channelContent);
    final episodes = <PodcastEpisode>[];

    for (final match in itemMatches) {
      final itemXml = match.group(1)!;

      // Enclosure extrahieren
      final enclosureUrl = _extractAttribute(itemXml, 'enclosure', 'url');
      if (enclosureUrl == null || enclosureUrl.trim().isEmpty) {
        // Ohne Audio-Enclosure ist das Item fuer einen Audioplayer nicht abspielbar
        continue;
      }

      final enclosureType =
          _extractAttribute(itemXml, 'enclosure', 'type') ?? 'audio/mpeg';
      final enclosureLengthStr =
          _extractAttribute(itemXml, 'enclosure', 'length') ?? '0';
      final enclosureLength = int.tryParse(enclosureLengthStr) ?? 0;

      final title = _extractTag(itemXml, 'title') ?? 'Unbenannte Episode';
      final guid = _extractTag(itemXml, 'guid') ?? enclosureUrl;
      final description = _extractTag(itemXml, 'description') ?? '';
      final shownotes = _extractTag(itemXml, 'content:encoded') ?? description;
      final pubDateStr = _extractTag(itemXml, 'pubDate');
      final pubDate = _parseRssDate(pubDateStr);

      final durationRaw = _extractTag(itemXml, 'itunes:duration');
      final durationMs = _parseDurationToMs(durationRaw);

      final episodeNumStr = _extractTag(itemXml, 'itunes:episode');
      final episodeNumber = int.tryParse(episodeNumStr ?? '');

      final seasonNumStr = _extractTag(itemXml, 'itunes:season');
      final seasonNumber = int.tryParse(seasonNumStr ?? '');

      final episodeImage =
          _extractAttribute(itemXml, 'itunes:image', 'href') ?? channelImage;

      // Eindeutige deterministische ID aus FeedUrl + GUID generieren
      final episodeId = 'ep_${_generateShortHash('$feedUrl:$guid')}';

      episodes.add(
        PodcastEpisode(
          id: episodeId,
          guid: guid,
          title: title,
          description: description,
          shownotes: shownotes,
          pubDate: pubDate,
          durationMs: durationMs,
          audioUrl: enclosureUrl.trim(),
          audioType: enclosureType.trim(),
          audioLengthBytes: enclosureLength,
          imageUrl: episodeImage,
          episodeNumber: episodeNumber,
          seasonNumber: seasonNumber,
        ),
      );
    }

    return PodcastFeed(
      feedUrl: feedUrl,
      title: channelTitle,
      description: channelDescription,
      author: channelAuthor,
      link: channelLink,
      imageUrl: channelImage,
      language: channelLanguage,
      episodes: episodes,
    );
  }

  String _preprocessXml(String xml) {
    return xml.trim();
  }

  /// Extrahiert den Textinhalt eines XML-Tags inklusive CDATA-Bereinigung.
  String? _extractTag(String xml, String tagName) {
    // Unterstuetzt Tags mit Namespace oder Attributen, z. B. <title> oder <itunes:author>
    final regex = RegExp(
      '<$tagName(?:\\s+[^>]*)?>([\\s\\S]*?)<\\/$tagName>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(xml);
    if (match == null) return null;

    var content = match.group(1)!.trim();

    // CDATA-Bloecke auspacken
    final cdataRegex =
        RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>', caseSensitive: false);
    content = content.replaceAllMapped(cdataRegex, (m) => m.group(1)!);

    return _unescapeHtml(content.trim());
  }

  /// Extrahiert ein Attribut aus einem selbstschliessenden oder regulaeren Tag.
  String? _extractAttribute(String xml, String tagName, String attrName) {
    final regex = RegExp(
      '<$tagName\\s+[^>]*?$attrName\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = regex.firstMatch(xml);
    if (match == null) return null;
    return _unescapeHtml(match.group(1)!.trim());
  }

  /// Wandelt gaengige XML-HTML-Entities zurueck.
  String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// Parst iTunes-Dauerformate ("HH:MM:SS", "MM:SS", oder Sekunden in int).
  int _parseDurationToMs(String? duration) {
    if (duration == null || duration.isEmpty) return 0;
    final trimmed = duration.trim();

    // Fall 1: Reine Sekundenanzahl (z. B. "3600")
    final asSeconds = int.tryParse(trimmed);
    if (asSeconds != null) {
      return asSeconds * 1000;
    }

    // Fall 2: HH:MM:SS oder MM:SS
    final parts = trimmed.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600 + m * 60 + s) * 1000;
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60 + s) * 1000;
    }

    return 0;
  }

  /// Parst RFC 822 / 2822 / ISO 8601 Datumsangaben.
  DateTime? _parseRssDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final trimmed = dateStr.trim();

    try {
      // 1. Standard ISO-8601 Versuch
      return DateTime.parse(trimmed);
    } catch (_) {
      // 2. RFC 822 / 1123 / 2822 Versuch: "Mon, 02 Jan 2006 15:04:05 MST"
      return _parseRfc822(trimmed);
    }
  }

  DateTime? _parseRfc822(String rfcDate) {
    // Bsp: "Tue, 15 Jan 2024 10:30:00 +0100" oder "15 Jan 2024 10:30:00 GMT"
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    final regex = RegExp(
      r'(?:[A-Za-z]+,\s+)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})(?:\s+([+-]\d{4}|[A-Za-z]+))?',
    );

    final match = regex.firstMatch(rfcDate);
    if (match == null) return null;

    final day = int.parse(match.group(1)!);
    final monthStr = match.group(2)!;
    final month = months[monthStr] ?? 1;
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  String _generateShortHash(String input) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    final bytes = utf8.encode(input);

    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0x7FFFFFFFFFFFFFFF;
    }

    return hash.toRadixString(16);
  }
}
