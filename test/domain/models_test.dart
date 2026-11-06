import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/bookmark.dart';
import 'package:nocturne/domain/models/chapter.dart';
import 'package:nocturne/domain/models/media_item.dart';
import 'package:nocturne/domain/models/playback_position.dart';

void main() {
  group('PlaybackPosition Tests', () {
    test('Standard-Konstruktor und fromMilliseconds initialisieren korrekt',
        () {
      const pos1 = PlaybackPosition(duration: Duration(seconds: 75));
      expect(pos1.milliseconds, 75000);
      expect(pos1.duration.inSeconds, 75);
      expect(pos1.isValid, isTrue);

      final pos2 = PlaybackPosition.fromMilliseconds(120000);
      expect(pos2.duration.inMinutes, 2);
      expect(pos2.milliseconds, 120000);
      expect(pos2.isValid, isTrue);

      // Negative Werte werden bei fromMilliseconds auf 0 geklammert
      final posNeg = PlaybackPosition.fromMilliseconds(-500);
      expect(posNeg.milliseconds, 0);
      expect(posNeg.duration, Duration.zero);
      expect(posNeg.isValid, isTrue);

      const invalidPos = PlaybackPosition(duration: Duration(seconds: -10));
      expect(invalidPos.isValid, isFalse);
    });

    test('Arithmetische Operatoren (+, -) klammern nicht-negativ', () {
      const pos = PlaybackPosition(duration: Duration(seconds: 60));

      final added = pos + const Duration(seconds: 30);
      expect(added.duration.inSeconds, 90);

      final subtracted = pos - const Duration(seconds: 40);
      expect(subtracted.duration.inSeconds, 20);

      // Subtraktion unter 0 wird auf Duration.zero geklammert
      final belowZero = pos - const Duration(seconds: 100);
      expect(belowZero.duration, Duration.zero);
      expect(belowZero.milliseconds, 0);

      // Addition mit negativer Duration unter 0 klammert ebenfalls
      final addedNeg = pos + const Duration(seconds: -120);
      expect(addedNeg.duration, Duration.zero);
    });

    test('difference berechnet exakte Differenz', () {
      const pos1 = PlaybackPosition(duration: Duration(seconds: 100));
      const pos2 = PlaybackPosition(duration: Duration(seconds: 40));

      expect(pos1.difference(pos2), const Duration(seconds: 60));
      expect(pos2.difference(pos1), const Duration(seconds: -60));
    });

    test('Vergleichsoperatoren und compareTo arbeiten erwartungsgemaess', () {
      const a = PlaybackPosition(duration: Duration(seconds: 10));
      const b = PlaybackPosition(duration: Duration(seconds: 20));
      const c = PlaybackPosition(duration: Duration(seconds: 10));

      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(b > a, isTrue);
      expect(b >= a, isTrue);
      expect(a <= c, isTrue);
      expect(a >= c, isTrue);

      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(a), isPositive);
      expect(a.compareTo(c), 0);

      expect(a == c, isTrue);
      expect(a == b, isFalse);
      expect(a.hashCode == c.hashCode, isTrue);
    });

    test('formatProgress formatiert mm:ss und hh:mm:ss', () {
      const shortPos =
          PlaybackPosition(duration: Duration(minutes: 3, seconds: 45));
      expect(shortPos.formatProgress(), '03:45');

      const longPos = PlaybackPosition(
          duration: Duration(hours: 2, minutes: 5, seconds: 9));
      expect(longPos.formatProgress(), '02:05:09');

      expect(PlaybackPosition.zero.formatProgress(), '00:00');
    });

    test(
        'formatRemaining formatiert verbleibende Zeit mit fuehrendem Minuszeichen',
        () {
      const total = Duration(hours: 1, minutes: 30);
      const pos = PlaybackPosition(duration: Duration(hours: 1, minutes: 10));

      // 20 Minuten verbleibend (< 1 Stunde Restzeit)
      expect(pos.formatRemaining(total), '-20:00');

      const posEarly = PlaybackPosition(duration: Duration(minutes: 15));
      // 1 Stunde 15 Minuten Restzeit
      expect(posEarly.formatRemaining(total), '-01:15:00');

      // Position ueberschreitet Total
      const posOver = PlaybackPosition(duration: Duration(hours: 2));
      expect(posOver.formatRemaining(total), '-00:00');
    });

    test('progressFraction berechnet Anteile von 0.0 bis 1.0', () {
      const total = Duration(minutes: 100);

      const posHalf = PlaybackPosition(duration: Duration(minutes: 50));
      expect(posHalf.progressFraction(total), closeTo(0.5, 0.001));

      const posFull = PlaybackPosition(duration: Duration(minutes: 100));
      expect(posFull.progressFraction(total), closeTo(1.0, 0.001));

      const posOver = PlaybackPosition(duration: Duration(minutes: 150));
      expect(posOver.progressFraction(total), 1.0);

      // Null oder negative Total-Dauer
      expect(posHalf.progressFraction(Duration.zero), 0.0);
      expect(posHalf.progressFraction(const Duration(seconds: -10)), 0.0);
    });

    test('copyWith, toMap und fromMap sind vollstaendig und symmetrisch', () {
      const original =
          PlaybackPosition(duration: Duration(milliseconds: 45230));
      final copied = original.copyWith(duration: const Duration(seconds: 10));
      expect(copied.duration.inSeconds, 10);

      final unmodified = original.copyWith();
      expect(unmodified, original);

      final map = original.toMap();
      expect(map['milliseconds'], 45230);

      final deserialized = PlaybackPosition.fromMap(map);
      expect(deserialized, original);
      expect(deserialized.toString(), contains('00:45'));
    });
  });

  group('Chapter Tests', () {
    test('Initialisierung und Getters funktionieren praezise', () {
      const chapter = Chapter(
        id: 'c-1',
        title: 'Kapitel 1: Der Anfang',
        start: Duration(minutes: 0),
        end: Duration(minutes: 15),
        index: 0,
      );

      expect(chapter.id, 'c-1');
      expect(chapter.title, 'Kapitel 1: Der Anfang');
      expect(chapter.startMs, 0);
      expect(chapter.endMs, 900000);
      expect(chapter.duration, const Duration(minutes: 15));
      expect(chapter.hasSubChapters, isFalse);
      expect(chapter.isValid, isTrue);
    });

    test('Validierungs-Assertions und isValid greifen bei unzulaessigen Werten',
        () {
      expect(
        () => Chapter(
          id: '',
          title: 'T',
          start: Duration.zero,
          end: const Duration(seconds: 10),
          index: 0,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Chapter(
          id: '1',
          title: '',
          start: Duration.zero,
          end: const Duration(seconds: 10),
          index: 0,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Chapter(
          id: '1',
          title: 'T',
          start: Duration.zero,
          end: const Duration(seconds: 10),
          index: -1,
        ),
        throwsA(isA<AssertionError>()),
      );

      const invalidOrder = Chapter(
        id: '1',
        title: 'T',
        start: Duration(seconds: 20),
        end: Duration(seconds: 10),
        index: 0,
      );
      expect(invalidOrder.isValid, isFalse);
    });

    test('containsPosition erkennt Kapitelgrenzen exakt', () {
      const chapter = Chapter(
        id: 'c-1',
        title: 'Kapitel 1',
        start: Duration(seconds: 10),
        end: Duration(seconds: 50),
        index: 0,
      );

      expect(
          chapter.containsPosition(
              const PlaybackPosition(duration: Duration(seconds: 10))),
          isTrue);
      expect(
          chapter.containsPosition(
              const PlaybackPosition(duration: Duration(seconds: 30))),
          isTrue);
      expect(
          chapter.containsPosition(
              const PlaybackPosition(duration: Duration(seconds: 50))),
          isTrue);

      expect(
          chapter.containsPosition(
              const PlaybackPosition(duration: Duration(seconds: 9))),
          isFalse);
      expect(
          chapter.containsPosition(
              const PlaybackPosition(duration: Duration(seconds: 51))),
          isFalse);
    });

    test('findActiveChapter loest hierarchische Unterkapitel rekursiv auf', () {
      const sub1 = Chapter(
        id: 'sub-1',
        title: 'Abschnitt 1.1',
        start: Duration(minutes: 0),
        end: Duration(minutes: 5),
        index: 0,
      );

      const sub2 = Chapter(
        id: 'sub-2',
        title: 'Abschnitt 1.2',
        start: Duration(minutes: 5),
        end: Duration(minutes: 10),
        index: 1,
      );

      const root = Chapter(
        id: 'root-1',
        title: 'Hauptkapitel 1',
        start: Duration(minutes: 0),
        end: Duration(minutes: 10),
        index: 0,
        subChapters: [sub1, sub2],
      );

      expect(root.hasSubChapters, isTrue);

      // Position bei 2 Min -> Sub-Kapitel 1.1
      final activeSub1 = root.findActiveChapter(
          const PlaybackPosition(duration: Duration(minutes: 2)));
      expect(activeSub1, sub1);

      // Position bei 7 Min -> Sub-Kapitel 1.2
      final activeSub2 = root.findActiveChapter(
          const PlaybackPosition(duration: Duration(minutes: 7)));
      expect(activeSub2, sub2);

      // Position ausserhalb -> null
      final outside = root.findActiveChapter(
          const PlaybackPosition(duration: Duration(minutes: 15)));
      expect(outside, isNull);
    });

    test('Hierarchisches toMap und fromMap bleiben verlustfrei', () {
      const sub = Chapter(
        id: 'sub-1',
        title: 'Teil 1',
        start: Duration(seconds: 0),
        end: Duration(seconds: 30),
        index: 0,
      );

      const root = Chapter(
        id: 'c-1',
        title: 'Kapitel',
        start: Duration(seconds: 0),
        end: Duration(seconds: 60),
        index: 0,
        subChapters: [sub],
      );

      final map = root.toMap();
      final restored = Chapter.fromMap(map);

      expect(restored, root);
      expect(restored.subChapters.length, 1);
      expect(restored.subChapters.first, sub);

      final copied = root.copyWith(title: 'Neuer Titel');
      expect(copied.title, 'Neuer Titel');
      expect(copied.id, root.id);

      expect(root.toString(), contains('Kapitel'));
    });
  });

  group('Bookmark Tests', () {
    test('Erstellung und Attributpruefung', () {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 'bm-1',
        mediaItemId: 'media-1',
        position: const PlaybackPosition(
            duration: Duration(minutes: 12, seconds: 30)),
        createdAt: now,
        label: 'Schlafunterbrechung',
        note: 'Hier war die Szene im Zug',
      );

      expect(bookmark.id, 'bm-1');
      expect(bookmark.mediaItemId, 'media-1');
      expect(bookmark.positionMs, 750000);
      expect(bookmark.createdAt, now);
      expect(bookmark.label, 'Schlafunterbrechung');
      expect(bookmark.note, 'Hier war die Szene im Zug');
    });

    test('Assertion bei leerer ID oder mediaItemId', () {
      final now = DateTime.now();
      expect(
        () => Bookmark(
          id: '',
          mediaItemId: 'm1',
          position: PlaybackPosition.zero,
          createdAt: now,
          label: 'L',
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Bookmark(
          id: 'b1',
          mediaItemId: '',
          position: PlaybackPosition.zero,
          createdAt: now,
          label: 'L',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith, toMap und fromMap', () {
      final now = DateTime.utc(2026, 11, 6, 10, 0, 0);
      final bm = Bookmark(
        id: 'bm-2',
        mediaItemId: 'media-42',
        position: const PlaybackPosition(duration: Duration(seconds: 400)),
        createdAt: now,
        label: 'Wichtiger Hinweis',
      );

      final copied = bm.copyWith(note: 'Nachtraegliche Notiz');
      expect(copied.note, 'Nachtraegliche Notiz');
      expect(copied.id, bm.id);

      final map = bm.toMap();
      expect(map['positionMs'], 400000);
      expect(map['label'], 'Wichtiger Hinweis');

      final restored = Bookmark.fromMap(map);
      expect(restored, bm);
      expect(restored.hashCode, bm.hashCode);
      expect(bm.toString(), contains('Wichtiger Hinweis'));
    });
  });

  group('MediaItem & MediaType Tests', () {
    late AudioSourceRef testSource;

    setUp(() {
      testSource =
          const AudioSourceRef.file('/storage/audiobook.m4b', title: 'Buch 1');
    });

    test('Alle Medientypen werden unterstuetzt', () {
      const types = [
        MediaType.audiobook,
        MediaType.podcastEpisode,
        MediaType.youTubeAudio,
        MediaType.youTubeVideo,
      ];
      expect(types.length, 4);

      final audiobook = MediaItem(
        id: 'ab-1',
        title: 'Hoerbuch Titel',
        type: MediaType.audiobook,
        source: testSource,
      );
      expect(audiobook.isAudiobook, isTrue);
      expect(audiobook.isPodcast, isFalse);
      expect(audiobook.isYouTube, isFalse);

      final podcast = audiobook.copyWith(type: MediaType.podcastEpisode);
      expect(podcast.isPodcast, isTrue);
      expect(podcast.isAudiobook, isFalse);

      final ytAudio = audiobook.copyWith(type: MediaType.youTubeAudio);
      expect(ytAudio.isYouTubeAudio, isTrue);
      expect(ytAudio.isYouTube, isTrue);

      final ytVideo = audiobook.copyWith(type: MediaType.youTubeVideo);
      expect(ytVideo.isYouTubeVideo, isTrue);
      expect(ytVideo.isYouTube, isTrue);
    });

    test('Kapitelsuche mit getChapterAt liefert das richtige Kapitel', () {
      const c1 = Chapter(
        id: 'c1',
        title: 'Kapitel 1',
        start: Duration(seconds: 0),
        end: Duration(seconds: 60),
        index: 0,
      );
      const c2 = Chapter(
        id: 'c2',
        title: 'Kapitel 2',
        start: Duration(seconds: 61),
        end: Duration(seconds: 120),
        index: 1,
      );

      final item = MediaItem(
        id: 'm1',
        title: 'Test',
        type: MediaType.audiobook,
        source: testSource,
        chapters: [c1, c2],
      );

      expect(item.hasChapters, isTrue);
      expect(
          item.getChapterAt(
              const PlaybackPosition(duration: Duration(seconds: 30))),
          c1);
      expect(
          item.getChapterAt(
              const PlaybackPosition(duration: Duration(seconds: 90))),
          c2);
      expect(
          item.getChapterAt(
              const PlaybackPosition(duration: Duration(seconds: 200))),
          isNull);
    });

    test('progressFraction berechnet Fortschritt bezogen auf duration', () {
      final itemWithDur = MediaItem(
        id: 'm1',
        title: 'Test',
        type: MediaType.podcastEpisode,
        source: testSource,
        duration: const Duration(minutes: 60),
        lastPosition: const PlaybackPosition(duration: Duration(minutes: 30)),
      );
      expect(itemWithDur.progressFraction, closeTo(0.5, 0.001));

      final itemNoDur = MediaItem(
        id: 'm2',
        title: 'Test 2',
        type: MediaType.podcastEpisode,
        source: testSource,
        duration: null,
      );
      expect(itemNoDur.progressFraction, 0.0);
    });

    test('Validierung verhindert leere ID oder leeren Titel', () {
      expect(
        () => MediaItem(
          id: '',
          title: 'Titel',
          type: MediaType.audiobook,
          source: testSource,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => MediaItem(
          id: 'id-1',
          title: '',
          type: MediaType.audiobook,
          source: testSource,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Symmetrische Serialisierung toMap und fromMap', () {
      final now = DateTime.utc(2026, 11, 6, 9, 30);
      const chapter = Chapter(
        id: 'c1',
        title: 'Kapitel 1',
        start: Duration.zero,
        end: Duration(minutes: 10),
        index: 0,
      );

      final item = MediaItem(
        id: 'item-100',
        title: 'Dune: Der Wuestenplanet',
        type: MediaType.audiobook,
        source: testSource,
        author: 'Frank Herbert',
        album: 'Dune Zyklus',
        duration: const Duration(hours: 21, minutes: 2),
        coverArtUri: 'file:///covers/dune.jpg',
        chapters: [chapter],
        lastPosition: const PlaybackPosition(duration: Duration(minutes: 45)),
        isCompleted: false,
        lastPlayedAt: now,
        metadata: {'bitrate': 128, 'codec': 'aac'},
      );

      final map = item.toMap();
      expect(map['title'], 'Dune: Der Wuestenplanet');
      expect(map['type'], 'audiobook');

      final restored = MediaItem.fromMap(map);
      expect(restored, item);
      expect(restored.hashCode, item.hashCode);
      expect(restored.toString(), contains('Dune: Der Wuestenplanet'));

      final copied = item.copyWith(isCompleted: true);
      expect(copied.isCompleted, isTrue);
      expect(copied == item, isFalse);
    });
  });
}
