import 'package:path/path.dart' as p;

/// Exception thrown when a path traversal, null-byte injection,
/// or invalid path manipulation attempt is detected.
class SecurityException implements Exception {
  const SecurityException(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityException &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SecurityException: $message';
}

/// Utility for validating and sanitizing file and directory paths.
///
/// Defends against:
/// - Directory traversal attacks (`../`, `..\`, `foo/../../etc/passwd`)
/// - Single and multi-layer percent-encoded traversal (`%2e%2e%2f`, `%252e%252e`)
/// - Raw and URL-encoded null-byte injections (`\x00`, `%00`)
/// - Unauthorized escapes from configured sandbox root directories
class PathSanitizer {
  const PathSanitizer._();

  /// Sanitizes [userPath] ensuring it stays strictly within [rootDir] (or equals [rootDir]).
  ///
  /// Throws [SecurityException] if:
  /// - [userPath] or [rootDir] contains a raw null byte (`\x00`).
  /// - URL-decoding results in a null byte.
  /// - URL-decoding fails due to malformed percent-encoding.
  /// - Path traversal is detected escaping [rootDir].
  ///
  /// Returns the canonicalized target path.
  static String sanitize(String userPath, {required String rootDir}) {
    if (userPath.contains('\x00')) {
      throw const SecurityException('Path contains invalid null byte');
    }
    if (rootDir.contains('\x00')) {
      throw const SecurityException('Root directory contains invalid null byte');
    }

    String decoded = userPath;
    try {
      int decodeRounds = 0;
      while (decoded.contains('%') && decodeRounds < 10) {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) {
          break;
        }
        decoded = next;
        decodeRounds++;
      }
    } on ArgumentError catch (e) {
      throw SecurityException('Invalid percent-encoded path: ${e.message}');
    } on FormatException catch (e) {
      throw SecurityException('Invalid percent-encoded path: ${e.message}');
    }

    if (decoded.contains('\x00')) {
      throw const SecurityException('Decoded path contains null byte');
    }

    // Normalize backslashes to forward slashes for universal cross-platform traversal defense
    final normalizedDecoded = decoded.replaceAll(r'\', '/');
    final canonicalRoot = p.canonicalize(rootDir);

    final String targetToCanonicalize;
    if (p.isAbsolute(normalizedDecoded) ||
        normalizedDecoded.startsWith('/') ||
        normalizedDecoded.startsWith(r'\')) {
      targetToCanonicalize = normalizedDecoded;
    } else {
      targetToCanonicalize = p.join(canonicalRoot, normalizedDecoded);
    }
    final canonicalTarget = p.canonicalize(targetToCanonicalize);

    if (!p.isWithin(canonicalRoot, canonicalTarget) && canonicalRoot != canonicalTarget) {
      throw SecurityException('Path traversal detected: target "$canonicalTarget" is outside root "$canonicalRoot"');
    }

    return canonicalTarget;
  }

  /// Verifies whether [targetPath] safely resolves within at least one of [allowedRoots]
  /// (or equals one of [allowedRoots]).
  ///
  /// Returns `false` if [targetPath] contains null bytes, invalid encodings,
  /// or escapes all allowed roots.
  static bool isSafeWithinRoots(String targetPath, List<String> allowedRoots) {
    if (allowedRoots.isEmpty) {
      return false;
    }
    if (targetPath.contains('\x00')) {
      return false;
    }

    String decoded = targetPath;
    try {
      int decodeRounds = 0;
      while (decoded.contains('%') && decodeRounds < 10) {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) {
          break;
        }
        decoded = next;
        decodeRounds++;
      }
    } catch (_) {
      return false;
    }

    if (decoded.contains('\x00')) {
      return false;
    }

    final normalizedDecoded = decoded.replaceAll(r'\', '/');

    for (final root in allowedRoots) {
      if (root.contains('\x00')) {
        continue;
      }
      final canonicalRoot = p.canonicalize(root);
      final String targetToCanonicalize;
      if (p.isAbsolute(normalizedDecoded) ||
          normalizedDecoded.startsWith('/') ||
          normalizedDecoded.startsWith(r'\')) {
        targetToCanonicalize = normalizedDecoded;
      } else {
        targetToCanonicalize = p.join(canonicalRoot, normalizedDecoded);
      }
      final canonicalTarget = p.canonicalize(targetToCanonicalize);

      if (p.isWithin(canonicalRoot, canonicalTarget) || canonicalRoot == canonicalTarget) {
        return true;
      }
    }

    return false;
  }
}
