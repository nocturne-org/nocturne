import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Injektor fuer Metadaten (ID3v2-Tags und Cover-Bilder) in heruntergeladene Audiodateien.
abstract class TagInjector {
  /// Erzeugt einen validen ID3v2.3 Byte-Header mit Titel, Kuenstler/Uploader, Album und Cover.
  static Uint8List buildId3v2Tag({
    required String title,
    String? artist,
    String? album,
    List<int>? coverBytes,
    String coverMime = 'image/jpeg',
  }) {
    final frames = <int>[];

    void addTextFrame(String frameId, String text) {
      if (text.isEmpty) return;
      final encoded = utf8.encode(text);
      final payload = [3, ...encoded]; // 3 = UTF-8
      final size = payload.length;

      frames.addAll(ascii.encode(frameId));
      frames.addAll([
        (size >> 24) & 0xFF,
        (size >> 16) & 0xFF,
        (size >> 8) & 0xFF,
        size & 0xFF,
      ]);
      frames.addAll([0, 0]); // Flags
      frames.addAll(payload);
    }

    addTextFrame('TIT2', title);
    if (artist != null) addTextFrame('TPE1', artist);
    if (album != null) addTextFrame('TALB', album);

    if (coverBytes != null && coverBytes.isNotEmpty) {
      final mimeBytes = ascii.encode(coverMime);
      final apicPayload = <int>[
        0, // ISO-8859-1
        ...mimeBytes,
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
        size & 0xFF,
      ]);
      frames.addAll([0, 0]);
      frames.addAll(apicPayload);
    }

    final tagSize = frames.length;
    // Synchsafe-Size (7 Bits pro Byte)
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

  /// Injiziert ID3v2-Tags in eine existierende Audiodatei.
  static Future<void> injectTagsIntoFile({
    required File targetFile,
    required String title,
    String? artist,
    String? album,
    List<int>? coverBytes,
  }) async {
    if (!await targetFile.exists()) return;

    final tagBytes = buildId3v2Tag(
      title: title,
      artist: artist,
      album: album,
      coverBytes: coverBytes,
    );

    final originalBytes = await targetFile.readAsBytes();

    // Pruefen, ob die Datei bereits einen ID3-Header hat
    var skipOffset = 0;
    if (originalBytes.length >= 10 &&
        originalBytes[0] == 0x49 &&
        originalBytes[1] == 0x44 &&
        originalBytes[2] == 0x33) {
      final existingSize = ((originalBytes[6] & 0x7F) << 21) |
          ((originalBytes[7] & 0x7F) << 14) |
          ((originalBytes[8] & 0x7F) << 7) |
          (originalBytes[9] & 0x7F);
      skipOffset = 10 + existingSize;
      if (skipOffset > originalBytes.length) skipOffset = 0;
    }

    final audioPayload =
        skipOffset > 0 ? originalBytes.sublist(skipOffset) : originalBytes;

    final output = Uint8List(tagBytes.length + audioPayload.length);
    output.setRange(0, tagBytes.length, tagBytes);
    output.setRange(tagBytes.length, output.length, audioPayload);

    await targetFile.writeAsBytes(output);
  }
}
