import 'dart:async';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../../domain/models/audio/audio_source_ref.dart';
import '../../domain/repositories/audio_player_repository.dart';
import 'audio_focus_manager.dart';

/// Adapter fuer `just_audio`, der das [AudioPlayerRepository]-Interface implementiert
/// und vollstaendiges AudioFocus-Management sowie Track-Vorabladung (Pre-Buffering) bereitstellt.
class JustAudioPlayerAdapter implements AudioPlayerRepository {
  final just_audio.AudioPlayer _player;
  final just_audio.AudioPlayer? _prebufferPlayer;
  final AudioFocusManager? _focusManager;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  StreamSubscription<just_audio.PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<double>? _volumeSub;

  double _userVolume = 1.0;
  bool _isDisposed = false;
  DateTime _lastPositionEmission = DateTime.fromMillisecondsSinceEpoch(0);

  JustAudioPlayerAdapter({
    just_audio.AudioPlayer? player,
    just_audio.AudioPlayer? prebufferPlayer,
    AudioFocusManager? focusManager,
  })  : _player = player ?? just_audio.AudioPlayer(),
        _prebufferPlayer = prebufferPlayer ?? just_audio.AudioPlayer(),
        _focusManager = focusManager {
    _initStreams();
    _initFocusHandling();
  }

  void _initStreams() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      final status = _mapPlayerStateToStatus(state);
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    });

    // Drosselung auf max. 4 Events/Sekunde zur Schonung der Bedtime-CPU
    _positionSub = _player.positionStream.listen((pos) {
      final now = DateTime.now();
      if (now.difference(_lastPositionEmission).inMilliseconds >= 250) {
        _lastPositionEmission = now;
        if (!_positionController.isClosed) {
          _positionController.add(pos);
        }
      }
    });

    _durationSub = _player.durationStream.listen((d) {
      if (!_durationController.isClosed) {
        _durationController.add(d);
      }
    });

    _volumeSub = _player.volumeStream.listen((v) {
      if (!_volumeController.isClosed) {
        _volumeController.add(v);
      }
    });
  }

  void _initFocusHandling() {
    _focusManager?.initialize();
  }

  AudioPlaybackStatus _mapPlayerStateToStatus(just_audio.PlayerState state) {
    switch (state.processingState) {
      case just_audio.ProcessingState.idle:
        return AudioPlaybackStatus.idle;
      case just_audio.ProcessingState.loading:
        return AudioPlaybackStatus.loading;
      case just_audio.ProcessingState.buffering:
        return AudioPlaybackStatus.buffering;
      case just_audio.ProcessingState.ready:
        return state.playing
            ? AudioPlaybackStatus.playing
            : AudioPlaybackStatus.paused;
      case just_audio.ProcessingState.completed:
        return AudioPlaybackStatus.completed;
    }
  }

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
    final startPos = (initialPosition != null && initialPosition < Duration.zero)
        ? Duration.zero
        : initialPosition;

    switch (source.type) {
      case AudioSourceType.file:
        await _player.setFilePath(source.uri, initialPosition: startPos);
        break;
      case AudioSourceType.safContentUri:
      case AudioSourceType.networkStream:
        await _player.setUrl(source.uri, initialPosition: startPos);
        break;
    }
  }

  /// Laedt den naechsten Track im Hintergrund vor, um unterbrechungsfreies
  /// Umschalten ohne Pufferpausen zu ermoeglichen.
  Future<void> preloadNextTrack(AudioSourceRef nextSource) async {
    final prebuffer = _prebufferPlayer;
    if (prebuffer == null) return;

    try {
      switch (nextSource.type) {
        case AudioSourceType.file:
          await prebuffer.setFilePath(nextSource.uri, preload: true);
          break;
        case AudioSourceType.safContentUri:
        case AudioSourceType.networkStream:
          await prebuffer.setUrl(nextSource.uri, preload: true);
          break;
      }
    } catch (_) {
      // Fehlgeschlagenes Pre-Buffering blockiert nicht die aktive Wiedergabe
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final clamped = position < Duration.zero ? Duration.zero : position;
    await _player.seek(clamped);
  }

  @override
  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_userVolume);
  }

  /// Passt die Lautstaerke temporaer fuer Ducking an (factor zwischen 0.0 und 1.0).
  Future<void> applyDuckFactor(double factor) async {
    final target = (_userVolume * factor).clamp(0.0, 1.0);
    await _player.setVolume(target);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _volumeSub?.cancel();

    await _statusController.close();
    await _positionController.close();
    await _durationController.close();
    await _volumeController.close();

    await _focusManager?.dispose();
    await _player.dispose();
    await _prebufferPlayer?.dispose();
  }
}
