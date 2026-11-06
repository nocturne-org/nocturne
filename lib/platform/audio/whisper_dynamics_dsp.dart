import 'dart:math' as math;
import 'dart:typed_data';

/// Konfiguration fuer den Whisper-Dynamics DSP-Audio-Filter (TICK-018).
class WhisperDynamicsConfig {
  /// Kompressor-Ratio (Standard: 4:1).
  final double compressionRatio;

  /// Limiter-Schwellenwert in dBFS (Standard: -3.0 dBFS).
  final double limiterThresholdDbfs;

  /// Attack-Zeit in Millisekunden (< 10 ms, Standard: 5.0 ms).
  final double attackTimeMs;

  /// Release-Zeit in Millisekunden (Standard: 60.0 ms).
  final double releaseTimeMs;

  /// Cutoff-Frequenz des High-Shelf Zischlaut-Filters in Hz (Standard: 4500 Hz).
  final double highShelfCutoffHz;

  /// Absenkung des High-Shelf Filters in dB (Standard: -6.0 dB).
  final double highShelfGainDb;

  /// Abtastrate des Audiosignals in Hz (Standard: 44100 Hz).
  final int sampleRate;

  const WhisperDynamicsConfig({
    this.compressionRatio = 4.0,
    this.limiterThresholdDbfs = -3.0,
    this.attackTimeMs = 5.0,
    this.releaseTimeMs = 60.0,
    this.highShelfCutoffHz = 4500.0,
    this.highShelfGainDb = -6.0,
    this.sampleRate = 44100,
  })  : assert(compressionRatio >= 1.0, 'Ratio must be >= 1.0'),
        assert(limiterThresholdDbfs <= 0.0, 'Limiter threshold must be <= 0 dBFS'),
        assert(attackTimeMs > 0.0 && attackTimeMs < 10.0, 'Attack must be < 10 ms'),
        assert(highShelfCutoffHz > 0.0, 'Cutoff must be > 0 Hz');

  /// Standardkonfiguration gemaess Nocturne-Architektur.
  static const WhisperDynamicsConfig bedtimeDefault = WhisperDynamicsConfig();

  /// Maximal zulaessige lineare Amplitude entsprechend dem Limiter-Schwellenwert.
  double get maxLinearAmplitude => math.pow(10.0, limiterThresholdDbfs / 20.0).toDouble();

  /// Lineare Absenkung des High-Shelf Filters.
  double get highShelfLinearGain => math.pow(10.0, highShelfGainDb / 20.0).toDouble();
}

/// DSP-Audio-Filter fuer Whisper-Dynamics gemaess Nocturne-Spezifikation (TICK-018):
/// 1. High-Shelf Filter ab 4.5 kHz (-6 dB) daempft scharfe Zischlaute ("S", "Z").
/// 2. Dynamik-Kompressor (Ratio 4:1, Attack < 10 ms) mit -3 dBFS Spitzen-Limiter
///    schuetzt den Schlafenden vor ploetzlichen Lautstaerkespruengen bei Sprache und Musik.
class WhisperDynamicsDsp {
  final WhisperDynamicsConfig config;

  // Koeffizienten des 2nd-Order Biquad High-Shelf Filters
  late double _b0, _b1, _b2, _a1, _a2;

  // IIR Filter-Zustaende
  double _x1 = 0.0, _x2 = 0.0;
  double _y1 = 0.0, _y2 = 0.0;

  // Kompressor-Envelope
  double _envelope = 0.0;
  late double _attackCoeff;
  late double _releaseCoeff;

  WhisperDynamicsDsp({
    this.config = WhisperDynamicsConfig.bedtimeDefault,
  }) {
    _calculateCoefficients();
  }

  void _calculateCoefficients() {
    // 1. High-Shelf Biquad Filter (Audio EQ Cookbook)
    final a = math.pow(10.0, config.highShelfGainDb / 40.0).toDouble();
    final omega = 2.0 * math.pi * (config.highShelfCutoffHz / config.sampleRate);
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    const q = 0.7071; // Butterworth-Glaette
    final alpha = sinOmega / (2.0 * q);
    final sqrtA = math.sqrt(a);

    final b0 = a * ((a + 1.0) + (a - 1.0) * cosOmega + 2.0 * sqrtA * alpha);
    final b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosOmega);
    final b2 = a * ((a + 1.0) + (a - 1.0) * cosOmega - 2.0 * sqrtA * alpha);
    final a0 = (a + 1.0) - (a - 1.0) * cosOmega + 2.0 * sqrtA * alpha;
    final a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosOmega);
    final a2 = (a + 1.0) - (a - 1.0) * cosOmega - 2.0 * sqrtA * alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;

    // 2. Kompressor Attack / Release Zeitkonstanten
    final attackSamples = (config.attackTimeMs / 1000.0) * config.sampleRate;
    final releaseSamples = (config.releaseTimeMs / 1000.0) * config.sampleRate;
    _attackCoeff = math.exp(-1.0 / attackSamples);
    _releaseCoeff = math.exp(-1.0 / releaseSamples);
  }

  /// Verarbeitet ein einzelnes Audiosample und gibt das gefilterte Sample zurueck.
  double processSample(double input) {
    // 1. High-Shelf Filter anwenden
    final filtered = _b0 * input + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = filtered;

    // 2. Dynamikkompression & Limiter anwenden
    final absVal = filtered.abs();

    if (absVal > _envelope) {
      _envelope = _attackCoeff * _envelope + (1.0 - _attackCoeff) * absVal;
    } else {
      _envelope = _releaseCoeff * _envelope + (1.0 - _releaseCoeff) * absVal;
    }

    final threshold = config.maxLinearAmplitude;
    var compressed = filtered;

    if (_envelope > threshold) {
      final envDb = linearToDb(_envelope);
      final threshDb = config.limiterThresholdDbfs;
      final overDb = envDb - threshDb;
      final compressedDb = threshDb + (overDb / config.compressionRatio);
      final gain = dbToLinear(compressedDb) / _envelope;
      compressed = filtered * gain;
    }

    // 3. Spitzenbegrenzung (Hard Limiter) strikt auf maxLinearAmplitude (-3 dBFS)
    if (compressed > threshold) {
      compressed = threshold;
    } else if (compressed < -threshold) {
      compressed = -threshold;
    }

    return compressed;
  }

  /// Verarbeitet einen Block von Audiosamples (PCM Puffer).
  Float32List processBuffer(Float32List inputBuffer) {
    final output = Float32List(inputBuffer.length);
    for (var i = 0; i < inputBuffer.length; i++) {
      output[i] = processSample(inputBuffer[i]);
    }
    return output;
  }

  /// Hilfsfunktion: Konvertiert lineare Amplitude in Dezibel (dBFS).
  static double linearToDb(double linear) {
    if (linear <= 0.0000000001) return -100.0;
    return 20.0 * (math.log(linear) / math.ln10);
  }

  /// Hilfsfunktion: Konvertiert Dezibel (dBFS) in lineare Amplitude.
  static double dbToLinear(double db) {
    return math.pow(10.0, db / 20.0).toDouble();
  }

  /// Setzt die internen Verzögerungsspeicher und den Envelope zurueck.
  void reset() {
    _x1 = 0.0;
    _x2 = 0.0;
    _y1 = 0.0;
    _y2 = 0.0;
    _envelope = 0.0;
  }
}
