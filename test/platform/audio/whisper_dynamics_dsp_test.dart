import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/audio/whisper_dynamics_dsp.dart';

void main() {
  group('WhisperDynamicsDsp Unit Tests (TICK-018)', () {
    late WhisperDynamicsDsp dsp;

    setUp(() {
      dsp = WhisperDynamicsDsp(
        config: const WhisperDynamicsConfig(
          compressionRatio: 4.0,
          limiterThresholdDbfs: -3.0,
          attackTimeMs: 5.0,
          releaseTimeMs: 50.0,
          highShelfCutoffHz: 4500.0,
          highShelfGainDb: -6.0,
          sampleRate: 44100,
        ),
      );
    });

    test('Configuration parameters match Nocturne architecture specification', () {
      expect(dsp.config.compressionRatio, 4.0);
      expect(dsp.config.limiterThresholdDbfs, -3.0);
      expect(dsp.config.attackTimeMs, lessThan(10.0));
      expect(dsp.config.highShelfCutoffHz, 4500.0);
      expect(dsp.config.highShelfGainDb, -6.0);
      // -3 dBFS entspricht ca. 0.7079 linearer Maximalamplitude
      expect(dsp.config.maxLinearAmplitude, closeTo(0.7079, 0.001));
    });

    test('Quiet signals below threshold (-14 dBFS) pass uncompressed', () {
      // 0.2 entspricht ca. -14 dBFS
      const lowFreqTone = 500.0; // 500 Hz liegt weit unter dem High-Shelf Cutoff
      final samples = Float32List(100);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = 0.2 * math.sin(2 * math.pi * lowFreqTone * i / 44100);
      }

      final processed = dsp.processBuffer(samples);

      // Nach Einschwingen bleibt die Amplitude bei ca. 0.2
      final maxOutput = processed.skip(30).map((s) => s.abs()).reduce(math.max);
      expect(maxOutput, closeTo(0.2, 0.02));
    });

    test('Loud signal peaks (0 dBFS = 1.0) are strictly limited to -3 dBFS', () {
      // 1000 Samples mit voller Maximallautstaerke 1.0 (0 dBFS)
      final samples = Float32List(1000);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = math.sin(2 * math.pi * 1000.0 * i / 44100);
      }

      final processed = dsp.processBuffer(samples);

      // Jedes einzelne Ausgangssample darf maximal die -3 dBFS Schwelle erreichen
      final maxLinear = dsp.config.maxLinearAmplitude;
      for (var i = 0; i < processed.length; i++) {
        expect(
          processed[i].abs(),
          lessThanOrEqualTo(maxLinear + 0.0001),
          reason: 'Sample $i (${processed[i]}) exceeded -3 dBFS limit ($maxLinear)',
        );
      }
    });

    test('High-shelf filter attenuates frequencies above 4.5 kHz by -6 dB', () {
      // 1. Tiefton (500 Hz): Darf kaum gedaempft werden (Verstaerkung ~ 1.0)
      dsp.reset();
      final lowTone = Float32List(1000);
      for (var i = 0; i < lowTone.length; i++) {
        lowTone[i] = 0.3 * math.sin(2 * math.pi * 500.0 * i / 44100);
      }
      final processedLow = dsp.processBuffer(lowTone);
      final maxLow = processedLow.skip(200).map((s) => s.abs()).reduce(math.max);
      expect(maxLow, closeTo(0.3, 0.03));

      // 2. Zischlaut / Hochton (10000 Hz): Muss um ca. -6 dB gedaempft werden
      // Lineare Verstaerkung bei -6 dB = 10^(-6/20) = ca. 0.501
      // 0.3 * 0.501 = ca. 0.150
      dsp.reset();
      final highTone = Float32List(1000);
      for (var i = 0; i < highTone.length; i++) {
        highTone[i] = 0.3 * math.sin(2 * math.pi * 10000.0 * i / 44100);
      }
      final processedHigh = dsp.processBuffer(highTone);
      final maxHigh = processedHigh.skip(200).map((s) => s.abs()).reduce(math.max);

      expect(maxHigh, closeTo(0.15, 0.03));
      expect(maxHigh, lessThan(maxLow * 0.6));
    });

    test('linearToDb and dbToLinear convert accurately', () {
      expect(WhisperDynamicsDsp.linearToDb(1.0), closeTo(0.0, 0.001));
      expect(WhisperDynamicsDsp.linearToDb(0.5), closeTo(-6.02, 0.01));
      expect(WhisperDynamicsDsp.dbToLinear(0.0), closeTo(1.0, 0.001));
      expect(WhisperDynamicsDsp.dbToLinear(-6.0), closeTo(0.501, 0.01));
    });
  });
}
