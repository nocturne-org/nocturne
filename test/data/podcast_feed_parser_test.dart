import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/podcast/podcast_feed_parser.dart';

void main() {
  group('PodcastFeedParser Tests', () {
    const parser = PodcastFeedParser();

    const sampleRssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title><![CDATA[Nocturne Gute-Nacht-Geschichten]]></title>
    <description><![CDATA[Entspannende Geschichten zum Einschlafen & Traeumen.]]></description>
    <link>https://nocturne.app/podcast</link>
    <language>de-DE</language>
    <itunes:author>Nocturne Audio Studio</itunes:author>
    <itunes:image href="https://nocturne.app/cover.jpg"/>
    
    <!-- Episode 1: Vollstaendige iTunes-Tags und Enclosure -->
    <item>
      <title><![CDATA[Folge 1: Der verwunschene Wald]]></title>
      <guid isPermaLink="false">guid-ep-001</guid>
      <description><![CDATA[Eine beruhigende Wanderung durch die Daemmerung.]]></description>
      <content:encoded><![CDATA[<p>Ausfuehrliche Shownotes mit binauralen Klaengen.</p>]]></content:encoded>
      <pubDate>Mon, 01 Jan 2024 22:00:00 GMT</pubDate>
      <itunes:duration>01:15:30</itunes:duration>
      <itunes:episode>1</itunes:episode>
      <itunes:season>1</itunes:season>
      <enclosure url="https://nocturne.app/ep1.mp3" length="54000000" type="audio/mpeg" />
      <itunes:image href="https://nocturne.app/ep1.jpg" />
    </item>

    <!-- Episode 2: MM:SS Dauer und m4a-Enclosure -->
    <item>
      <title>Folge 2: Regen auf dem Dach</title>
      <guid>guid-ep-002</guid>
      <description>Sanfte Regengeraeusche fuer tiefen Schlaf.</description>
      <pubDate>Tue, 02 Jan 2024 22:00:00 +0100</pubDate>
      <itunes:duration>45:20</itunes:duration>
      <itunes:episode>2</itunes:episode>
      <enclosure url="https://nocturne.app/ep2.m4a" length="32000000" type="audio/mp4" />
    </item>

    <!-- Episode 3: Dauer als reine Sekundenangabe -->
    <item>
      <title>Folge 3: Meeresrauschen</title>
      <guid>guid-ep-003</guid>
      <pubDate>2024-01-03T21:00:00Z</pubDate>
      <itunes:duration>3600</itunes:duration>
      <enclosure url="https://nocturne.app/ep3.opus" length="25000000" type="audio/ogg" />
    </item>

    <!-- Nicht-Audio-Item ohne Enclosure (sollte uebersprungen werden) -->
    <item>
      <title>Textankuendigung ohne Audio</title>
      <guid>guid-text-only</guid>
      <description>Nur Text, keine Audiodatei.</description>
    </item>
  </channel>
</rss>''';

    test('Parst Kanalmetadaten vollstaendig', () {
      final feed = parser.parse(
        xmlContent: sampleRssXml,
        feedUrl: 'https://nocturne.app/rss.xml',
      );

      expect(feed.title, 'Nocturne Gute-Nacht-Geschichten');
      expect(feed.description, contains('Entspannende Geschichten'));
      expect(feed.link, 'https://nocturne.app/podcast');
      expect(feed.author, 'Nocturne Audio Studio');
      expect(feed.language, 'de-DE');
      expect(feed.imageUrl, 'https://nocturne.app/cover.jpg');
    });

    test('Extrahiert alle Audio-Episoden und ignoriert Non-Audio-Items', () {
      final feed = parser.parse(
        xmlContent: sampleRssXml,
        feedUrl: 'https://nocturne.app/rss.xml',
      );

      expect(feed.episodes.length, 3);
    });

    test('Parst Episode 1 mit CDATA, Shownotes und HH:MM:SS Dauer', () {
      final feed = parser.parse(
        xmlContent: sampleRssXml,
        feedUrl: 'https://nocturne.app/rss.xml',
      );

      final ep1 = feed.episodes[0];
      expect(ep1.title, 'Folge 1: Der verwunschene Wald');
      expect(ep1.guid, 'guid-ep-001');
      expect(ep1.description, contains('Eine beruhigende Wanderung'));
      expect(ep1.shownotes, contains('Ausfuehrliche Shownotes'));
      expect(ep1.audioUrl, 'https://nocturne.app/ep1.mp3');
      expect(ep1.audioType, 'audio/mpeg');
      expect(ep1.audioLengthBytes, 54000000);
      expect(ep1.durationMs, (1 * 3600 + 15 * 60 + 30) * 1000);
      expect(ep1.episodeNumber, 1);
      expect(ep1.seasonNumber, 1);
      expect(ep1.imageUrl, 'https://nocturne.app/ep1.jpg');
      expect(ep1.pubDate, isNotNull);
      expect(ep1.pubDate!.year, 2024);
      expect(ep1.pubDate!.month, 1);
      expect(ep1.pubDate!.day, 1);
    });

    test('Parst MM:SS Dauer und Sekunden-Dauer korrekt', () {
      final feed = parser.parse(
        xmlContent: sampleRssXml,
        feedUrl: 'https://nocturne.app/rss.xml',
      );

      final ep2 = feed.episodes[1];
      expect(ep2.durationMs, (45 * 60 + 20) * 1000);
      expect(ep2.audioType, 'audio/mp4');

      final ep3 = feed.episodes[2];
      expect(ep3.durationMs, 3600 * 1000);
    });

    test('Konvertiert Episode in MediaItem fuer den Audio-Player', () {
      final feed = parser.parse(
        xmlContent: sampleRssXml,
        feedUrl: 'https://nocturne.app/rss.xml',
      );

      final ep1 = feed.episodes[0];
      final mediaItem = ep1.toMediaItem(
        podcastTitle: feed.title,
        feedAuthor: feed.author,
      );

      expect(mediaItem.id, ep1.id);
      expect(mediaItem.title, ep1.title);
      expect(mediaItem.author, 'Nocturne Audio Studio');
      expect(mediaItem.album, 'Nocturne Gute-Nacht-Geschichten');
      expect(mediaItem.durationMs, ep1.durationMs);
      expect(mediaItem.source.isStream, isTrue);
      expect(mediaItem.source.uri, ep1.audioUrl);
      expect(mediaItem.extraMetadata['podcast_title'],
          'Nocturne Gute-Nacht-Geschichten');
    });
  });
}
