/// Kandidat fuer einen Audiostream aus einem Stream-Manifest.
class AudioStreamCandidate {
  const AudioStreamCandidate({
    required this.url,
    required this.mimeType,
    required this.bitrateKbps,
    required this.codec,
    required this.container,
    this.contentLengthBytes,
  });

  final String url;
  final String mimeType;
  final int bitrateKbps;
  final String codec;
  final String container;
  final int? contentLengthBytes;

  @override
  String toString() =>
      'AudioStreamCandidate($container, $codec, ${bitrateKbps}kbps)';
}

/// Berechnung der Bandbreiten- und Akku-Einsparungen im reinen Audio-Modus.
class BandwidthSavings {
  const BandwidthSavings({
    required this.audioBitrateKbps,
    required this.videoBitrateKbps,
    required this.savingsPercentage,
    required this.megabytesPerHourAudio,
    required this.megabytesPerHourVideo,
  });

  final int audioBitrateKbps;
  final int videoBitrateKbps;
  final double savingsPercentage;
  final double megabytesPerHourAudio;
  final double megabytesPerHourVideo;

  /// Ob die Einsparung das Zielkriterium von mindestens 85% erfuellt.
  bool get meets85PercentTarget => savingsPercentage >= 85.0;

  @override
  String toString() =>
      'BandwidthSavings(${savingsPercentage.toStringAsFixed(1)}% Ersparnis: ${megabytesPerHourAudio.toStringAsFixed(1)} MB/h vs ${megabytesPerHourVideo.toStringAsFixed(1)} MB/h)';
}

/// Puffer-Konfiguration fuer schnellen Wiedergabestart (< 800 ms).
class StreamBufferConfig {
  const StreamBufferConfig({
    this.initialBufferDurationMs = 800,
    this.bufferForPlaybackMs = 500,
    this.minBufferDurationSec = 15,
    this.maxBufferDurationSec = 60,
  });

  /// Initiale Vorpuffrung in Millisekunden fuer Wiedergabebeginn (Ziel: <= 800 ms).
  final int initialBufferDurationMs;

  /// Puffergroesse vor Beginn der Audioausgabe (500 ms).
  final int bufferForPlaybackMs;

  /// Minimaler Puffer waehrend der laufenden Wiedergabe in Sekunden.
  final int minBufferDurationSec;

  /// Maximaler Puffer zur Begrenzung von Speicherverbrauch.
  final int maxBufferDurationSec;
}

/// Filtert und waehlt optimale reine Audiostreams (M4A / Opus) mit maximaler
/// Daten- und Akku-Ersparnis.
class AudioOnlyStreamSelector {
  const AudioOnlyStreamSelector();

  /// Waehlt den qualitativ besten Audio-Stream aus einer Liste von Stream-Formaten.
  /// Video-Streams werden vollstaendig verworfen.
  AudioStreamCandidate? selectBestAudioStream(
    List<Map<String, dynamic>> rawFormats, {
    bool preferOpus = true,
  }) {
    final candidates = <AudioStreamCandidate>[];

    for (final f in rawFormats) {
      final mime = (f['mimeType'] ?? f['type'] ?? '') as String;
      // Strikter Filter: Video-Streams komplett ausschliessen
      if (!mime.startsWith('audio/') || mime.startsWith('video/')) {
        continue;
      }

      final url = (f['url'] ?? '') as String;
      if (url.isEmpty) continue;

      final bitrateBps = (f['bitrate'] as num?)?.toInt() ?? 128000;
      final bitrateKbps = bitrateBps ~/ 1000;

      final isOpus = mime.contains('opus') || mime.contains('webm');
      final container = isOpus ? 'opus' : 'm4a';
      final codec = isOpus ? 'opus' : 'aac';
      final contentLength = int.tryParse((f['contentLength'] ?? '').toString());

      candidates.add(
        AudioStreamCandidate(
          url: url,
          mimeType: mime,
          bitrateKbps: bitrateKbps,
          codec: codec,
          container: container,
          contentLengthBytes: contentLength,
        ),
      );
    }

    if (candidates.isEmpty) return null;

    // Priorisierung:
    // 1. Opus mit 128-160 kbps (hohe Transparenz bei Sprache)
    // 2. M4A mit 128-160 kbps
    // 3. Andere Raten am naechsten zu 128 kbps
    candidates.sort((a, b) {
      final aScore = _scoreCandidate(a, preferOpus: preferOpus);
      final bScore = _scoreCandidate(b, preferOpus: preferOpus);
      return bScore.compareTo(aScore); // Hoechste Punktzahl zuerst
    });

    return candidates.first;
  }

  int _scoreCandidate(AudioStreamCandidate c, {required bool preferOpus}) {
    var score = 0;

    // Bevorzugtes Format
    if (c.container == 'opus' && preferOpus) {
      score += 50;
    } else if (c.container == 'm4a') {
      score += 40;
    }

    // Ideale Bitrate: 128 bis 160 kbps
    if (c.bitrateKbps >= 128 && c.bitrateKbps <= 160) {
      score += 100;
    } else if (c.bitrateKbps > 160) {
      // Zu hohe Bitrate verschwendet Bandbreite ohne Hoervorteil beim Einschlafen
      score += 60;
    } else {
      // < 128 kbps
      score += c.bitrateKbps;
    }

    return score;
  }

  /// Berechnet die Bandbreiteneinsparung gegenueber einem Standard-Videostream (z. B. 1080p bei 3500 kbps).
  BandwidthSavings calculateSavings(
    int audioBitrateKbps, {
    int referenceVideoBitrateKbps = 3500,
  }) {
    final diff = referenceVideoBitrateKbps - audioBitrateKbps;
    final percentage = (diff / referenceVideoBitrateKbps) * 100.0;

    // MB pro Stunde: (kbps * 3600s) / (8 * 1024)
    final mbPerHourAudio = (audioBitrateKbps * 3600.0) / 8192.0;
    final mbPerHourVideo = (referenceVideoBitrateKbps * 3600.0) / 8192.0;

    return BandwidthSavings(
      audioBitrateKbps: audioBitrateKbps,
      videoBitrateKbps: referenceVideoBitrateKbps,
      savingsPercentage: percentage,
      megabytesPerHourAudio: mbPerHourAudio,
      megabytesPerHourVideo: mbPerHourVideo,
    );
  }

  /// Liefert die optimierte Puffer-Konfiguration fuer einen schnellen Start (< 800 ms).
  StreamBufferConfig getOptimalBufferConfig() {
    return const StreamBufferConfig(
      initialBufferDurationMs: 800,
      bufferForPlaybackMs: 500,
      minBufferDurationSec: 15,
      maxBufferDurationSec: 60,
    );
  }
}
