import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/data/parser/audio_metadata.dart';
import 'package:nocturne/data/parser/media_metadata_parser.dart';

Uint8List _createId3v2Tag({
  required String title,
  required String author,
  required String album,
  required int track,
  required int year,
  List<int>? coverBytes,
}) {
  final frames = <int>[];

  void addTextFrame(String id, String text) {
    final textBytes = utf8.encode(text);
    final payload = [3, ...textBytes]; // Encoding 3 = UTF-8
    final size = payload.length;

    // Frame Header: ID(4) + Size(4) + Flags(2)
    frames.addAll(ascii.encode(id));
    frames.addAll([
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF
    ]);
    frames.addAll([0, 0]);
    frames.addAll(payload);
  }

  addTextFrame('TIT2', title);
  addTextFrame('TPE1', author);
  addTextFrame('TALB', album);
  addTextFrame('TRCK', '$track');
  addTextFrame('TYER', '$year');

  if (coverBytes != null) {
    final apicPayload = <int>[
      0, // ISO-8859-1
      ...ascii.encode('image/jpeg'),
      0, // Null
      3, // Front cover
      0, // Description empty
      ...coverBytes,
    ];
    final size = apicPayload.length;
    frames.addAll(ascii.encode('APIC'));
    frames.addAll([
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF
    ]);
    frames.addAll([0, 0]);
    frames.addAll(apicPayload);
  }

  final tagSize = frames.length;
  // Synchsafe Tag Size
  final b0 = (tagSize >> 21) & 0x7F;
  final b1 = (tagSize >> 14) & 0x7F;
  final b2 = (tagSize >> 7) & 0x7F;
  final b3 = tagSize & 0x7F;

  final header = [
    0x49, 0x44, 0x33, // 'ID3'
    3, 0, // v2.3
    0, // Flags
    b0, b1, b2, b3,
  ];

  return Uint8List.fromList([...header, ...frames]);
}

Uint8List _createM4bWithChpl({
  required String title,
  required String author,
  required List<(int, String)> chaptersMs,
}) {
  final chplEntries = <int>[];
  for (final chap in chaptersMs) {
    final ms = chap.$1;
    final name = chap.$2;
    final nameBytes = utf8.encode(name);

    // 100ns units = ms * 10,000
    final units100ns = ms * 10000;
    final high = (units100ns ~/ 4294967296) & 0xFFFFFFFF;
    final low = units100ns & 0xFFFFFFFF;

    chplEntries.addAll([
      (high >> 24) & 0xFF,
      (high >> 16) & 0xFF,
      (high >> 8) & 0xFF,
      high & 0xFF,
      (low >> 24) & 0xFF,
      (low >> 16) & 0xFF,
      (low >> 8) & 0xFF,
      low & 0xFF,
      nameBytes.length,
      ...nameBytes,
    ]);
  }

  final chplPayload = [
    1, 0, 0, 0, // Version + Flags
    (chaptersMs.length >> 24) & 0xFF,
    (chaptersMs.length >> 16) & 0xFF,
    (chaptersMs.length >> 8) & 0xFF,
    chaptersMs.length & 0xFF,
    ...chplEntries,
  ];
  final chplSize = 8 + chplPayload.length;
  final chplAtom = [
    (chplSize >> 24) & 0xFF,
    (chplSize >> 16) & 0xFF,
    (chplSize >> 8) & 0xFF,
    chplSize & 0xFF,
    ...ascii.encode('chpl'),
    ...chplPayload,
  ];

  List<int> makeDataAtom(String text) {
    final tBytes = utf8.encode(text);
    final dataSize = 16 + tBytes.length;
    return [
      (dataSize >> 24) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 8) & 0xFF,
      dataSize & 0xFF,
      ...ascii.encode('data'),
      0, 0, 0, 1, // Type string
      0, 0, 0, 0, // Locale
      ...tBytes,
    ];
  }

  final titleData = makeDataAtom(title);
  final titleSize = 8 + titleData.length;
  final titleAtom = [
    (titleSize >> 24) & 0xFF,
    (titleSize >> 16) & 0xFF,
    (titleSize >> 8) & 0xFF,
    titleSize & 0xFF,
    ...latin1.encode('©nam'),
    ...titleData,
  ];

  final authorData = makeDataAtom(author);
  final authorSize = 8 + authorData.length;
  final authorAtom = [
    (authorSize >> 24) & 0xFF,
    (authorSize >> 16) & 0xFF,
    (authorSize >> 8) & 0xFF,
    authorSize & 0xFF,
    ...latin1.encode('©ART'),
    ...authorData,
  ];

  final ilstPayload = [...titleAtom, ...authorAtom];
  final ilstSize = 8 + ilstPayload.length;
  final ilstAtom = [
    (ilstSize >> 24) & 0xFF,
    (ilstSize >> 16) & 0xFF,
    (ilstSize >> 8) & 0xFF,
    ilstSize & 0xFF,
    ...ascii.encode('ilst'),
    ...ilstPayload,
  ];

  final metaPayload = [0, 0, 0, 0, ...ilstAtom]; // 4 bytes flags + ilst
  final metaSize = 8 + metaPayload.length;
  final metaAtom = [
    (metaSize >> 24) & 0xFF,
    (metaSize >> 16) & 0xFF,
    (metaSize >> 8) & 0xFF,
    metaSize & 0xFF,
    ...ascii.encode('meta'),
    ...metaPayload,
  ];

  final udtaPayload = [...metaAtom, ...chplAtom];
  final udtaSize = 8 + udtaPayload.length;
  final udtaAtom = [
    (udtaSize >> 24) & 0xFF,
    (udtaSize >> 16) & 0xFF,
    (udtaSize >> 8) & 0xFF,
    udtaSize & 0xFF,
    ...ascii.encode('udta'),
    ...udtaPayload,
  ];

  final moovPayload = udtaAtom;
  final moovSize = 8 + moovPayload.length;
  final moovAtom = [
    (moovSize >> 24) & 0xFF,
    (moovSize >> 16) & 0xFF,
    (moovSize >> 8) & 0xFF,
    moovSize & 0xFF,
    ...ascii.encode('moov'),
    ...moovPayload,
  ];

  return Uint8List.fromList(moovAtom);
}

void main() {
  group('ID3 & M4B Metadaten- & Kapitel-Parser Tests (TICK-010)', () {
    const parser = MediaMetadataParser();

    test('ID3v2 extrahiert Titel, Autor, Album, Track, Jahr und Cover', () {
      final tagBytes = _createId3v2Tag(
        title: 'Die unendliche Geschichte',
        author: 'Michael Ende',
        album: 'Audiobooks Classic',
        track: 1,
        year: 1979,
        coverBytes: List.filled(64, 0xFF),
      );

      final meta = parser.parseBytes(tagBytes, 'track01.mp3');

      expect(meta.title, 'Die unendliche Geschichte');
      expect(meta.author, 'Michael Ende');
      expect(meta.album, 'Audiobooks Classic');
      expect(meta.trackNumber, 1);
      expect(meta.year, 1979);
      expect(meta.hasCover, isTrue);
      expect(meta.coverArtBytes?.length, 64);
      expect(meta.rawFormat, contains('ID3v2'));
    });

    test('M4B QuickTime Atome extrahieren Metadaten und Kapitelmarken (chpl)',
        () {
      final m4bBytes = _createM4bWithChpl(
        title: 'Der Herr der Ringe',
        author: 'J.R.R. Tolkien',
        chaptersMs: [
          (0, 'Prolog: Ueber Hobbits'),
          (60000, 'Kapitel 1: Ein lang erwartetes Fest'),
          (180000, 'Kapitel 2: Der Schatten der Vergangenheit'),
        ],
      );

      final meta = parser.parseBytes(m4bBytes, 'lotr.m4b');

      expect(meta.title, 'Der Herr der Ringe');
      expect(meta.author, 'J.R.R. Tolkien');
      expect(meta.hasChapters, isTrue);
      expect(meta.chapters.length, 3);

      expect(meta.chapters[0].title, 'Prolog: Ueber Hobbits');
      expect(meta.chapters[0].startMs, 0);
      expect(meta.chapters[0].endMs, 60000);

      expect(meta.chapters[1].title, 'Kapitel 1: Ein lang erwartetes Fest');
      expect(meta.chapters[1].startMs, 60000);
      expect(meta.chapters[1].endMs, 180000);
    });

    test(
        'Dateinamen-Fallback funktioniert zuverlaessig bei fehlenden Metadaten',
        () {
      // 1. Muster: "01 - Titel.mp3"
      final meta1 = parser.parseBytes(Uint8List(0), '01 - Die Gefaehrten.mp3');
      expect(meta1.title, 'Die Gefaehrten');
      expect(meta1.trackNumber, 1);
      expect(meta1.rawFormat, 'Filename-Fallback');

      // 2. Muster: "Autor - Titel.m4b"
      final meta2 =
          parser.parseBytes(Uint8List(0), 'Hermann Hesse - Siddhartha.m4b');
      expect(meta2.title, 'Siddhartha');
      expect(meta2.author, 'Hermann Hesse');

      // 3. Fallback ohne Trenner
      final meta3 = parser.parseBytes(Uint8List(0), 'bedtime_story.opus');
      expect(meta3.title, 'bedtime story');
    });

    test('extractAndSaveCover speichert Cover-Art sauber im Cache ab',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('nocturne_cover_test_');

      try {
        final meta = AudioMetadata(
          title: 'Cover Book',
          coverArtBytes: Uint8List.fromList([
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A
          ]), // PNG Signature
          coverMimeType: 'image/png',
        );

        final saved =
            await parser.extractAndSaveCover(meta, tempDir, 'media-123');

        expect(saved, isNotNull);
        expect(await saved!.exists(), isTrue);
        expect(saved.path, contains('media-123.png'));
        expect(await saved.length(), 8);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
