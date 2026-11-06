import 'dart:convert';
import 'dart:typed_data';

/// Kompakte, eigenstaendige SHA-256 Implementierung nach FIPS 180-4 / RFC 6234
/// fuer die kryptografische Integritaetspruefung der Remote-Config ohne externe Abhaengigkeiten.
abstract class Sha256Digest {
  static const List<int> _k = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
  static int _ch(int x, int y, int z) => ((x & y) ^ (~x & z)) & 0xFFFFFFFF;
  static int _maj(int x, int y, int z) =>
      ((x & y) ^ (x & z) ^ (y & z)) & 0xFFFFFFFF;
  static int _sigma0(int x) =>
      (_rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22)) & 0xFFFFFFFF;
  static int _sigma1(int x) =>
      (_rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25)) & 0xFFFFFFFF;
  static int _gamma0(int x) =>
      (_rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3)) & 0xFFFFFFFF;
  static int _gamma1(int x) =>
      (_rotr(x, 17) ^ _rotr(x, 19) ^ (x >> 10)) & 0xFFFFFFFF;

  /// Berechnet den hexadezimalen SHA-256 Hash eines Strings.
  static String computeHash(String input) {
    return computeBytesHash(utf8.encode(input));
  }

  /// Berechnet den hexadezimalen SHA-256 Hash beliebiger Binaerdaten.
  static String computeBytesHash(List<int> bytes) {
    final bitLength = bytes.length * 8;

    // Padding gemaess Spezifikation
    final paddingLength = (56 - (bytes.length + 1) % 64) % 64;
    final padded = Uint8List(bytes.length + 1 + paddingLength + 8);
    padded.setRange(0, bytes.length, bytes);
    padded[bytes.length] = 0x80;

    // 64-Bit Laenge in Big-Endian anhaengen
    final byteData = ByteData.view(padded.buffer);
    byteData.setUint32(padded.length - 4, bitLength & 0xFFFFFFFF);
    byteData.setUint32(padded.length - 8, (bitLength >> 32) & 0xFFFFFFFF);

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);

    for (var chunk = 0; chunk < padded.length; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = byteData.getUint32(chunk + i * 4);
      }
      for (var i = 16; i < 64; i++) {
        w[i] = (_gamma1(w[i - 2]) + w[i - 7] + _gamma0(w[i - 15]) + w[i - 16]) &
            0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final t1 = (h + _sigma1(e) + _ch(e, f, g) + _k[i] + w[i]) & 0xFFFFFFFF;
        final t2 = (_sigma0(a) + _maj(a, b, c)) & 0xFFFFFFFF;
        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = StringBuffer();
    for (final v in [h0, h1, h2, h3, h4, h5, h6, h7]) {
      out.write(v.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString().toLowerCase();
  }
}
