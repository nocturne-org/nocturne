import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';

/// Test-Implementierung zur Verifikation der Repository-Vertragsregeln.
class ContractVerifyingAudioPlayerRepository implements AudioPlayerRepository {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _isDisposed = false;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    _status = AudioPlaybackStatus.ready;
    _statusController.add(_status);
    if (initialPosition != null) {
      _position = initialPosition < Duration.zero ? Duration.zero : initialPosition;
      _positionController.add(_position);
    }
  }

  @override
  Future<void> play() async {
    _status = AudioPlaybackStatus.playing;
    _statusController.add(_status);
  }

  @override
  Future<void> pause() async {
    _status = AudioPlaybackStatus.paused;
    _statusController.add(_status);
  }

  @override
  Future<void> stop() async {
    _status = AudioPlaybackStatus.idle;
    _position = Duration.zero;
    _statusController.add(_status);
    _positionController.add(_position);
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position < Duration.zero ? Duration.zero : position;
    _positionController.add(_position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _volumeController.add(_volume);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _statusController.close();
    await _positionController.close();
    await _durationController.close();
    await _volumeController.close();
  }
}

void main() {
  group('AudioPlayerRepository Contract & Domain Tests', () {
    late ContractVerifyingAudioPlayerRepository repo;

    setUp(() {
      repo = ContractVerifyingAudioPlayerRepository();
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('Initialer Status und Lifecycle lassen sich steuern', () async {
      const source = AudioSourceRef.file('/sandbox/chapter1.m4b', title: 'Kapitel 1');
      expect(source.type, AudioSourceType.file);
      expect(source.title, 'Kapitel 1');

      unawaited(
        expectLater(
          repo.playbackStatusStream,
          emitsInOrder([
            AudioPlaybackStatus.ready,
            AudioPlaybackStatus.playing,
            AudioPlaybackStatus.paused,
            AudioPlaybackStatus.idle,
          ]),
        ),
      );

      await repo.setSource(source);
      await repo.play();
      await repo.pause();
      await repo.stop();
    });

    test('Lautstaerke wird strikt auf den Bereich 0.0 bis 1.0 geklammert', () async {
      unawaited(
        expectLater(
          repo.volumeStream,
          emitsInOrder([0.5, 1.0, 0.0]),
        ),
      );

      await repo.setVolume(0.5);
      await repo.setVolume(1.5); // Muss auf 1.0 geklammert werden
      await repo.setVolume(-0.2); // Muss auf 0.0 geklammert werden
    });

    test('Seek klammert negative Zeitspannen auf Duration.zero', () async {
      unawaited(
        expectLater(
          repo.positionStream,
          emitsInOrder([
            const Duration(seconds: 30),
            Duration.zero,
          ]),
        ),
      );

      await repo.seek(const Duration(seconds: 30));
      await repo.seek(const Duration(seconds: -15));
    });

    test('Streams erlauben mehrere gleichzeitige Abonnenten (Broadcast)', () {
      final sub1 = repo.playbackStatusStream.listen((_) {});
      final sub2 = repo.playbackStatusStream.listen((_) {});

      expect(sub1, isNotNull);
      expect(sub2, isNotNull);

      sub1.cancel();
      sub2.cancel();
    });

    test('Dispose ist idempotent und fuehrt bei Mehrfachaufruf zu keinem Fehler', () async {
      await repo.dispose();
      await repo.dispose(); // Zweiter Aufruf darf keine Exception werfen
    });
  });
}
