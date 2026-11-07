import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/storage/path_sanitizer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String rootDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nocturne_sanitizer_test_');
    rootDir = tempDir.path;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SecurityException', () {
    test('provides accurate message and toString representation', () {
      const exception = SecurityException('Unauthorized access attempt');

      expect(exception.message, equals('Unauthorized access attempt'));
      expect(
        exception.toString(),
        equals('SecurityException: Unauthorized access attempt'),
      );
    });

    test('implements value equality and hashCode', () {
      const exc1 = SecurityException('Traversal error');
      const exc2 = SecurityException('Traversal error');
      const exc3 = SecurityException('Different error');

      expect(exc1, equals(exc2));
      expect(exc1.hashCode, equals(exc2.hashCode));
      expect(exc1, isNot(equals(exc3)));
    });
  });

  group('PathSanitizer.sanitize - Valid Paths', () {
    test('sanitizes relative path inside root directory', () {
      final sanitized = PathSanitizer.sanitize(
        'audio_downloads/audiobook.mp3',
        rootDir: rootDir,
      );

      final expected = p.canonicalize(p.join(rootDir, 'audio_downloads/audiobook.mp3'));
      expect(sanitized, equals(expected));
    });

    test('sanitizes deeply nested relative path', () {
      final sanitized = PathSanitizer.sanitize(
        'a/b/c/d/chapter1.m4b',
        rootDir: rootDir,
      );

      final expected = p.canonicalize(p.join(rootDir, 'a/b/c/d/chapter1.m4b'));
      expect(sanitized, equals(expected));
    });

    test('resolves root directory itself when given empty or dot path', () {
      final sanitizedDot = PathSanitizer.sanitize('.', rootDir: rootDir);
      final sanitizedEmpty = PathSanitizer.sanitize('', rootDir: rootDir);

      final expectedRoot = p.canonicalize(rootDir);
      expect(sanitizedDot, equals(expectedRoot));
      expect(sanitizedEmpty, equals(expectedRoot));
    });

    test('accepts absolute path located strictly inside root directory', () {
      final absoluteInside = p.join(rootDir, 'covers', 'cover.jpg');
      final sanitized = PathSanitizer.sanitize(
        absoluteInside,
        rootDir: rootDir,
      );

      expect(sanitized, equals(p.canonicalize(absoluteInside)));
    });

    test('safely decodes valid percent-encoded characters in filename', () {
      final sanitized = PathSanitizer.sanitize(
        'Audio%20Books/Track%2001%20-%20Intro.mp3',
        rootDir: rootDir,
      );

      final expected = p.canonicalize(
        p.join(rootDir, 'Audio Books/Track 01 - Intro.mp3'),
      );
      expect(sanitized, equals(expected));
    });
  });

  group('PathSanitizer.sanitize - Traversal Attacks', () {
    test('rejects parent traversal ../ attempt', () {
      expect(
        () => PathSanitizer.sanitize('../', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects Windows-style parent traversal ..\\ attempt', () {
      expect(
        () => PathSanitizer.sanitize(r'..\', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects complex middle traversal foo/../../etc/passwd', () {
      expect(
        () => PathSanitizer.sanitize(
          'foo/../../etc/passwd',
          rootDir: rootDir,
        ),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects deep escape attempt escaping multiple root levels', () {
      expect(
        () => PathSanitizer.sanitize(
          'sub/nested/../../../../secret.key',
          rootDir: rootDir,
        ),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects absolute path pointing outside root directory', () {
      final outsidePath = Platform.isWindows ? r'C:\Windows\System32\cmd.exe' : '/etc/passwd';
      expect(
        () => PathSanitizer.sanitize(outsidePath, rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });
  });

  group('PathSanitizer.sanitize - URL-encoded Traversal', () {
    test('rejects percent-encoded traversal %2e%2e%2f', () {
      expect(
        () => PathSanitizer.sanitize('%2e%2e%2f', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects percent-encoded traversal with target file %2e%2e/secret.txt', () {
      expect(
        () => PathSanitizer.sanitize('%2e%2e/secret.txt', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects double percent-encoded traversal %252e%252e', () {
      expect(
        () => PathSanitizer.sanitize('%252e%252e', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects nested double percent-encoded traversal %252e%252e%252f', () {
      expect(
        () => PathSanitizer.sanitize('%252e%252e%252f', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects percent-encoded backslash traversal ..%5c', () {
      expect(
        () => PathSanitizer.sanitize('..%5c', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal detected'),
          ),
        ),
      );
    });

    test('rejects malformed percent-encoding sequences', () {
      expect(
        () => PathSanitizer.sanitize('invalid_%zz_token', rootDir: rootDir),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('PathSanitizer.sanitize - Null-Byte Injections', () {
    test('rejects raw null byte in userPath', () {
      expect(
        () => PathSanitizer.sanitize('foo\x00bar.mp3', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            equals('Path contains invalid null byte'),
          ),
        ),
      );
    });

    test('rejects raw null byte at beginning of userPath', () {
      expect(
        () => PathSanitizer.sanitize('\x00file.mp3', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            equals('Path contains invalid null byte'),
          ),
        ),
      );
    });

    test('rejects raw null byte in rootDir parameter', () {
      expect(
        () => PathSanitizer.sanitize('file.mp3', rootDir: '$rootDir\x00bad'),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            equals('Root directory contains invalid null byte'),
          ),
        ),
      );
    });

    test('rejects percent-encoded null byte %00', () {
      expect(
        () => PathSanitizer.sanitize('foo%00bar.mp3', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            equals('Decoded path contains null byte'),
          ),
        ),
      );
    });

    test('rejects double percent-encoded null byte %2500', () {
      expect(
        () => PathSanitizer.sanitize('foo%2500bar.mp3', rootDir: rootDir),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            equals('Decoded path contains null byte'),
          ),
        ),
      );
    });
  });

  group('PathSanitizer.isSafeWithinRoots', () {
    late Directory secondTempDir;
    late List<String> allowedRoots;

    setUp(() async {
      secondTempDir = await Directory.systemTemp.createTemp('nocturne_secondary_');
      allowedRoots = [rootDir, secondTempDir.path];
    });

    tearDown(() async {
      if (await secondTempDir.exists()) {
        await secondTempDir.delete(recursive: true);
      }
    });

    test('returns true for target residing inside primary allowed root', () {
      final safePath = p.join(rootDir, 'podcasts', 'ep1.mp3');
      expect(PathSanitizer.isSafeWithinRoots(safePath, allowedRoots), isTrue);
    });

    test('returns true for target residing inside secondary allowed root', () {
      final safePath = p.join(secondTempDir.path, 'downloads', 'ep2.mp3');
      expect(PathSanitizer.isSafeWithinRoots(safePath, allowedRoots), isTrue);
    });

    test('returns true when target path equals an allowed root exactly', () {
      expect(PathSanitizer.isSafeWithinRoots(rootDir, allowedRoots), isTrue);
      expect(PathSanitizer.isSafeWithinRoots(secondTempDir.path, allowedRoots), isTrue);
    });

    test('returns true for relative path resolving within first root', () {
      expect(PathSanitizer.isSafeWithinRoots('audiobook.m4b', allowedRoots), isTrue);
    });

    test('returns false for path outside all allowed roots', () {
      final outsidePath = Platform.isWindows ? r'C:\Windows\System32\drivers\etc\hosts' : '/etc/shadow';
      expect(PathSanitizer.isSafeWithinRoots(outsidePath, allowedRoots), isFalse);
    });

    test('returns false for traversal attempt ../', () {
      expect(PathSanitizer.isSafeWithinRoots('../escaped.txt', allowedRoots), isFalse);
    });

    test('returns false for Windows-style traversal attempt ..\\', () {
      expect(PathSanitizer.isSafeWithinRoots(r'..\escaped.txt', allowedRoots), isFalse);
    });

    test('returns false for percent-encoded traversal %2e%2e%2f', () {
      expect(PathSanitizer.isSafeWithinRoots('%2e%2e%2fescaped.txt', allowedRoots), isFalse);
    });

    test('returns false for double percent-encoded traversal %252e%252e', () {
      expect(PathSanitizer.isSafeWithinRoots('%252e%252e', allowedRoots), isFalse);
    });

    test('returns false when null-byte injection is present', () {
      expect(PathSanitizer.isSafeWithinRoots('valid/path\x00.mp3', allowedRoots), isFalse);
      expect(PathSanitizer.isSafeWithinRoots('valid/path%00.mp3', allowedRoots), isFalse);
    });

    test('returns false when allowedRoots list is empty', () {
      expect(PathSanitizer.isSafeWithinRoots(p.join(rootDir, 'file.mp3'), []), isFalse);
    });
  });
}
