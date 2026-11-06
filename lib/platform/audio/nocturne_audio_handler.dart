import 'dart:async';
import 'package:audio_service/audio_service.dart' as audio_service;
import '../../domain/models/media_item.dart' as domain;
import '../../domain/models/playback_position.dart';

/// Zentraler AudioHandler fuer Android MediaSessionService und System-Notification.
/// Steuert Wiedergabe, Benachrichtigungs-Aktionen (15s Vor-/Rueckspulen),
/// Headset- und Bluetooth-Tasten sowie Doze-Resistenz.
class NocturneAudioHandler extends audio_service.BaseAudioHandler
    with audio_service.SeekHandler {
  /// Standard-Spulintervall fuer Bedtime Audio (15 Sekunden).
  static const Duration defaultSeekInterval = Duration(seconds: 15);

  /// Benutzerdefiniertes Spulintervall.
  final Duration seekInterval;

  /// Optionale Callback-Funktion fuer externe Playback-Delegation.
  final Future<void> Function()? onPlayCallback;
  final Future<void> Function()? onPauseCallback;
  final Future<void> Function()? onStopCallback;
  final Future<void> Function(Duration position)? onSeekCallback;

  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  bool _isPlaying = false;

  NocturneAudioHandler({
    this.seekInterval = defaultSeekInterval,
    this.onPlayCallback,
    this.onPauseCallback,
    this.onStopCallback,
    this.onSeekCallback,
  }) {
    _initInitialState();
  }

  void _initInitialState() {
    playbackState.add(
      _buildPlaybackState(
        playing: false,
        processingState: audio_service.AudioProcessingState.idle,
        position: Duration.zero,
      ),
    );
  }

  /// Erzeugt den vollstaendigen [audio_service.PlaybackState] mit 15s Spulaktionen und Notification-Steuerung.
  audio_service.PlaybackState _buildPlaybackState({
    required bool playing,
    required audio_service.AudioProcessingState processingState,
    required Duration position,
    Duration? bufferedPosition,
  }) {
    final controls = [
      audio_service.MediaControl.rewind,
      if (playing)
        audio_service.MediaControl.pause
      else
        audio_service.MediaControl.play,
      audio_service.MediaControl.fastForward,
      audio_service.MediaControl.stop,
    ];

    return audio_service.PlaybackState(
      controls: controls,
      systemActions: const {
        audio_service.MediaAction.seek,
        audio_service.MediaAction.seekForward,
        audio_service.MediaAction.seekBackward,
        audio_service.MediaAction.playPause,
        audio_service.MediaAction.stop,
      },
      // 0: Rewind 15s, 1: Play/Pause, 2: FastForward 15s
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition ?? position,
      speed: 1.0,
      queueIndex: 0,
    );
  }

  /// Synchronisiert ein [domain.MediaItem] mit der System-MediaSession.
  void updateMediaItemFromDomain(domain.MediaItem item) {
    _totalDuration = item.duration;
    _currentPosition = item.lastPosition.duration;

    final uri = Uri.tryParse(item.coverArtUri ?? '');

    final serviceItem = audio_service.MediaItem(
      id: item.id,
      title: item.title,
      album: item.album ?? 'Nocturne',
      artist: item.author ?? 'Nocturne Bedtime Audio',
      duration: item.duration,
      artUri: uri != null && uri.hasScheme ? uri : null,
      extras: <String, dynamic>{
        'mediaType': item.type.name,
        'isCompleted': item.isCompleted,
      },
    );

    mediaItem.add(serviceItem);

    playbackState.add(
      _buildPlaybackState(
        playing: _isPlaying,
        processingState: audio_service.AudioProcessingState.ready,
        position: _currentPosition,
      ),
    );
  }

  /// Aktualisiert die Abspielposition (z. B. durch internen Player-Stream).
  void updatePosition(PlaybackPosition position) {
    _currentPosition = position.duration;
    playbackState.add(
      _buildPlaybackState(
        playing: _isPlaying,
        processingState: audio_service.AudioProcessingState.ready,
        position: _currentPosition,
      ),
    );
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    playbackState.add(
      _buildPlaybackState(
        playing: true,
        processingState: audio_service.AudioProcessingState.ready,
        position: _currentPosition,
      ),
    );

    if (onPlayCallback != null) {
      await onPlayCallback!();
    }
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    playbackState.add(
      _buildPlaybackState(
        playing: false,
        processingState: audio_service.AudioProcessingState.ready,
        position: _currentPosition,
      ),
    );

    if (onPauseCallback != null) {
      await onPauseCallback!();
    }
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentPosition = Duration.zero;

    playbackState.add(
      _buildPlaybackState(
        playing: false,
        processingState: audio_service.AudioProcessingState.idle,
        position: Duration.zero,
      ),
    );

    if (onStopCallback != null) {
      await onStopCallback!();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    var target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (_totalDuration != null && target > _totalDuration!) {
      target = _totalDuration!;
    }

    _currentPosition = target;

    playbackState.add(
      _buildPlaybackState(
        playing: _isPlaying,
        processingState: audio_service.AudioProcessingState.ready,
        position: _currentPosition,
      ),
    );

    if (onSeekCallback != null) {
      await onSeekCallback!(target);
    }
  }

  @override
  Future<void> fastForward() async {
    await seek(_currentPosition + seekInterval);
  }

  @override
  Future<void> rewind() async {
    final target = _currentPosition - seekInterval;
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> click(
      [audio_service.MediaButton button =
          audio_service.MediaButton.media]) async {
    switch (button) {
      case audio_service.MediaButton.media:
        if (_isPlaying) {
          await pause();
        } else {
          await play();
        }
        break;
      case audio_service.MediaButton.next:
        await fastForward();
        break;
      case audio_service.MediaButton.previous:
        await rewind();
        break;
    }
  }
}
