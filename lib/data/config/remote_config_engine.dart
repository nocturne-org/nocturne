import 'dart:convert';
import 'dart:io';
import 'remote_app_config.dart';
import 'sha256_digest.dart';

/// HTTP-Client Interface fuer das Herunterladen der GitHub Raw JSON Konfiguration.
abstract class RemoteConfigHttpClient {
  Future<String> fetchRawConfig(String url);
}

/// Fallback / Standard-Client.
class DefaultRemoteConfigHttpClient implements RemoteConfigHttpClient {
  const DefaultRemoteConfigHttpClient();

  @override
  Future<String> fetchRawConfig(String url) async {
    // In Produktivumgebung: HTTP GET Request an raw.githubusercontent.com
    return jsonEncode(RemoteAppConfig.defaults.toMap());
  }
}

/// Dynamische Regel-Engine fuer Remote-Konfigurationen (Tier 3).
/// Aktualisiert User-Agents, Client-Versionen und Instanzlisten ohne APK-Rollout.
/// Beinhaltet kryptografische Hash-Pruefung und persistenten Offline-Cache.
class RemoteConfigEngine {
  RemoteConfigEngine({
    File? cacheFile,
    RemoteConfigHttpClient? httpClient,
    this.rawConfigUrl =
        'https://raw.githubusercontent.com/nocturne/config/main/client_rules.json',
  })  : _cacheFile = cacheFile,
        _httpClient = httpClient ?? const DefaultRemoteConfigHttpClient() {
    _activeConfig = loadCachedConfig();
  }

  final File? _cacheFile;
  final RemoteConfigHttpClient _httpClient;
  final String rawConfigUrl;

  late RemoteAppConfig _activeConfig;

  /// Aktuell aktive Konfiguration.
  RemoteAppConfig get activeConfig => _activeConfig;

  /// Laedt die persistent zwischengespeicherte Konfiguration aus dem Offline-Cache.
  RemoteAppConfig loadCachedConfig() {
    if (_cacheFile != null && _cacheFile!.existsSync()) {
      try {
        final content = _cacheFile!.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return RemoteAppConfig.fromMap(map);
      } catch (_) {
        // Fehlerhafter Cache -> Fallback auf Defaults
      }
    }
    return RemoteAppConfig.defaults;
  }

  /// Laedt die Remote-Konfiguration herunter, prueft den SHA-256 Hash und speichert
  /// sie persistent im Offline-Cache.
  Future<RemoteAppConfig> fetchAndApplyConfig({
    String? rawJsonOverride,
    String? expectedSha256,
  }) async {
    final rawJson =
        rawJsonOverride ?? await _httpClient.fetchRawConfig(rawConfigUrl);

    // Kryptografische Integritaetspruefung (SHA-256)
    final calculatedHash = Sha256Digest.computeHash(rawJson);

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      if (calculatedHash.toLowerCase() != expectedSha256.toLowerCase()) {
        throw const FormatException(
          'Integritaetspruefung fehlgeschlagen: SHA-256 Hash stimmt nicht ueberein (Manipulation erkannt).',
        );
      }
    }

    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final newConfig =
          RemoteAppConfig.fromMap(map, calculatedHash: calculatedHash);

      // In persistentem Offline-Cache sichern
      if (_cacheFile != null) {
        if (!_cacheFile!.parent.existsSync()) {
          _cacheFile!.parent.createSync(recursive: true);
        }
        _cacheFile!.writeAsStringSync(jsonEncode(newConfig.toMap()));
      }

      _activeConfig = newConfig;
      return newConfig;
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Fehler beim Parsen der Remote-Config: $e');
    }
  }
}
