import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';

/// Mock-Implementierung fuer Interface-Verifikation im Test.
class MockAudioPlayerRepository implements AudioPlayerRepository {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _position = Duration.zero;
  double _volume = 1.0;

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
  Future<void> setSource(String uri, {Duration? initialPosition}) async {
    _status = AudioPlaybackStatus.ready;
    _statusController.add(_status);
    if (initialPosition != null) {
      _position = initialPosition;
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
    _position = position;
    _positionController.add(_position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _volumeController.add(_volume);
  }

  @override
  Future<void> dispose() async {
    await _statusController.close();
    await _positionController.close();
    await _durationController.close();
    await _volumeController.close();
  }
}

void main() {
  group('AudioPlayerRepository Domain Tests', () {
    late MockAudioPlayerRepository repo;

    setUp(() {
      repo = MockAudioPlayerRepository();
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('Initialer Status und Lifecycle lassen sich steuern', () async {
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

      await repo.setSource('https://example.com/audio.mp3');
      await repo.play();
      await repo.pause();
      await repo.stop();
    });

    test('Lautstaerke laesst sich praezise setzen und wird geklammert', () async {
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
  });
}
