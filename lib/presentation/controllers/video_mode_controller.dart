import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/audio/audio_source_ref.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../../platform/pip/pip_controller.dart';
import '../../platform/video/video_player_decoder_bridge.dart';
import '../providers/audio_providers.dart';
import '../state/video_playback_state.dart';

/// Zentraler Controller fuer den nahtlosen Wechsel zwischen Video- und Reinaudio-Wiedergabe
/// inklusive automatischer Freigabe des Hardware-Videodecoders im Audio-Modus,
/// automatischem Wechsel bei Display-Abschaltung und Android Picture-in-Picture (PiP).
class VideoModeController extends Notifier<VideoPlaybackState> {
  VideoModeController({
    AudioPlayerRepository? playerOverride,
    VideoDecoderBridge? videoDecoderOverride,
    PipController? pipControllerOverride,
  })  : _playerOverride = playerOverride,
        _videoDecoderOverride = videoDecoderOverride,
        _pipControllerOverride = pipControllerOverride;

  final AudioPlayerRepository? _playerOverride;
  final VideoDecoderBridge? _videoDecoderOverride;
  final PipController? _pipControllerOverride;

  AudioPlayerRepository get _player =>
      _playerOverride ?? ref.read(audioPlayerRepositoryProvider);

  late final VideoDecoderBridge _videoDecoder =
      _videoDecoderOverride ?? DefaultVideoDecoderBridge();

  late final PipController _pip = _pipControllerOverride ?? PipController();

  StreamSubscription<Duration>? _audioPosSub;
  StreamSubscription<Duration>? _videoPosSub;
  StreamSubscription<bool>? _screenStateSub;
  StreamSubscription<bool>? _pipStateSub;
  VideoPlaybackState? _manualState;

  @override
  VideoPlaybackState get state {
    try {
      return super.state;
    } catch (_) {
      return _manualState ?? const VideoPlaybackState();
    }
  }

  @override
  set state(VideoPlaybackState value) {
    try {
      super.state = value;
    } catch (_) {
      _manualState = value;
    }
  }

  @override
  VideoPlaybackState build() {
    _initSubscriptions();
    try {
      ref.onDispose(_cleanup);
    } catch (_) {
      // Isolierte Unit-Tests ohne ProviderContainer
    }
    return const VideoPlaybackState();
  }

  void _initSubscriptions() {
    _audioPosSub = _player.positionStream.listen((pos) {
      if (state.isAudioOnly) {
        state = state.copyWith(currentPosition: pos);
      }
    });

    _videoPosSub = _videoDecoder.positionStream.listen((pos) {
      if (state.isVideo) {
        state = state.copyWith(currentPosition: pos);
      }
    });

    // Ueberwacht Display Ein/Aus
    _screenStateSub = _pip.screenStateStream.listen((screenOn) {
      state = state.copyWith(isScreenOn: screenOn);
      if (!screenOn && state.isVideo) {
        // Beim Ausschalten des Bildschirms sofort in den akkuschonenden Audio-Modus wechseln
        switchToAudioOnly();
      }
    });

    // Ueberwacht PiP-Status
    _pipStateSub = _pip.pipModeStream.listen((inPip) {
      state = state.copyWith(isPipActive: inPip);
    });
  }

  void _cleanup() {
    _audioPosSub?.cancel();
    _videoPosSub?.cancel();
    _screenStateSub?.cancel();
    _pipStateSub?.cancel();
    _videoDecoder.release();
  }

  /// Initialisiert die verfuegbaren Medienstreams (Audio & optional Video).
  void setMediaStreams({
    required String audioUrl,
    String? videoUrl,
  }) {
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    state = state.copyWith(
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      isVideoAvailable: hasVideo,
    );
  }

  /// Schaltet nahtlos zwischen Video und Reinaudio um.
  Future<void> toggleMode() async {
    if (state.isAudioOnly) {
      await switchToVideo();
    } else {
      await switchToAudioOnly();
    }
  }

  /// Wechselt in den Videomodus bei erhaltener exakter Abspielposition.
  Future<void> switchToVideo() async {
    if (!state.isVideoAvailable || state.videoUrl == null) return;
    if (state.isVideo) return;

    final targetPos = state.currentPosition;

    // Audioplayer anhalten
    await _player.pause();

    // Hardware-Videodecoder initialisieren und starten
    await _videoDecoder.initialize(
      state.videoUrl!,
      initialPosition: targetPos,
    );
    await _videoDecoder.play();

    state = state.copyWith(
      mode: PlaybackPresentationMode.video,
      isDecoderAllocated: true,
      isPlaying: true,
    );
  }

  /// Wechselt nahtlos in den Reinaudio-Modus und gibt saemtliche Videodecoder-Ressourcen frei.
  Future<void> switchToAudioOnly() async {
    if (state.isAudioOnly) return;

    final targetPos = state.currentPosition;

    // Videodecoder stoppen und Ressourcen sofort freigeben (0 GPU-Last)
    await _videoDecoder.pause();
    await _videoDecoder.release();

    // Reinen Audioplayer an der synchronen Position starten
    if (state.audioUrl != null) {
      await _player.setSource(
        AudioSourceRef.remoteStream(streamUrl: state.audioUrl!),
        initialPosition: targetPos,
      );
      await _player.play();
    }

    state = state.copyWith(
      mode: PlaybackPresentationMode.audioOnly,
      isDecoderAllocated: false,
      isPipActive: false,
      isPlaying: true,
    );
  }

  /// Wird bei Verlassen der App oder Home-Geste ausgeloest.
  /// Startet automatisch den Picture-in-Picture Modus, falls Video aktiv ist.
  Future<bool> onAppBackgrounded() async {
    if (state.isVideo && !state.isPipActive) {
      final supported = await _pip.isPipSupported();
      if (supported) {
        return await _pip.enterPip();
      }
    }
    return false;
  }

  /// Informiert den Controller ueber eine manuelle Positionsaenderung.
  Future<void> seek(Duration position) async {
    state = state.copyWith(currentPosition: position);
    if (state.isVideo) {
      await _videoDecoder.seek(position);
    } else {
      await _player.seek(position);
    }
  }
}
