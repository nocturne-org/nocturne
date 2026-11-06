import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/repositories/audio_player_repository.dart';
import 'package:nocturne/platform/pip/pip_controller.dart';
import 'package:nocturne/platform/video/video_player_decoder_bridge.dart';
import 'package:nocturne/presentation/controllers/video_mode_controller.dart';
import 'package:nocturne/presentation/providers/audio_providers.dart';
import 'package:nocturne/presentation/state/video_playback_state.dart';

class MockAudioPlayerForVideoTest implements AudioPlayerRepository {
  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _volCtrl =
      StreamController<double>.broadcast();

  AudioPlaybackStatus status = AudioPlaybackStatus.idle;
  AudioSourceRef? source;
  Duration? lastInitialPos;
  int playCount = 0;
  int pauseCount = 0;

  @override
  Stream<AudioPlaybackStatus> get playbackStatusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;

  @override
  Stream<double> get volumeStream => _volCtrl.stream;

  @override
  Future<void> setSource(AudioSourceRef source, {Duration? initialPosition}) async {
    this.source = source;
    lastInitialPos = initialPosition;
    status = AudioPlaybackStatus.ready;
  }

  @override
  Future<void> play() async {
    playCount++;
    status = AudioPlaybackStatus.playing;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    status = AudioPlaybackStatus.paused;
  }

  @override
  Future<void> stop() async {
    status = AudioPlaybackStatus.idle;
  }

  @override
  Future<void> seek(Duration position) async {
    _posCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  void emitPosition(Duration pos) {
    _posCtrl.add(pos);
  }

  Future<void> dispose() async {
    await _statusCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _volCtrl.close();
  }
}

class MockVideoDecoderBridge implements VideoDecoderBridge {
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();

  bool allocated = false;
  int initializeCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int releaseCount = 0;
  Duration? lastInitialPos;

  @override
  bool get isAllocated => allocated;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> initialize(String videoUrl, {Duration? initialPosition}) async {
    allocated = true;
    initializeCount++;
    lastInitialPos = initialPosition;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    _posCtrl.add(position);
  }

  @override
  Future<void> release() async {
    allocated = false;
    releaseCount++;
  }

  void emitPosition(Duration pos) {
    _posCtrl.add(pos);
  }

  Future<void> dispose() async {
    await _posCtrl.close();
  }
}

class MockPipBridgeForVideoTest implements PipPlatformBridge {
  bool supported = true;
  int enterPipCount = 0;
  final StreamController<bool> _screenCtrl =
      StreamController<bool>.broadcast();

  @override
  Future<bool> isPipSupported() async => supported;

  @override
  Future<bool> enterPipMode({
    int aspectRatioNumerator = 16,
    int aspectRatioDenominator = 9,
  }) async {
    enterPipCount++;
    return true;
  }

  @override
  Stream<bool> get screenStateStream => _screenCtrl.stream;

  void emitScreen(bool on) {
    _screenCtrl.add(on);
  }

  Future<void> dispose() async {
    await _screenCtrl.close();
  }
}

void main() {
  group('VideoModeController Tests', () {
    late MockAudioPlayerForVideoTest mockAudioPlayer;
    late MockVideoDecoderBridge mockVideoDecoder;
    late MockPipBridgeForVideoTest mockPipBridge;
    late PipController pipController;
    late ProviderContainer container;

    setUp(() {
      mockAudioPlayer = MockAudioPlayerForVideoTest();
      mockVideoDecoder = MockVideoDecoderBridge();
      mockPipBridge = MockPipBridgeForVideoTest();
      pipController = PipController(platformBridge: mockPipBridge);

      container = ProviderContainer(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayer),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await mockAudioPlayer.dispose();
      await mockVideoDecoder.dispose();
      await pipController.dispose();
      await mockPipBridge.dispose();
    });

    test('Initialer Zustand ist Reinaudio mit nicht-allokiertem Decoder', () {
      final controller = VideoModeController(
        playerOverride: mockAudioPlayer,
        videoDecoderOverride: mockVideoDecoder,
        pipControllerOverride: pipController,
      );

      final state = controller.build();
      expect(state.mode, PlaybackPresentationMode.audioOnly);
      expect(state.isDecoderAllocated, isFalse);
      expect(mockVideoDecoder.isAllocated, isFalse);
    });

    test('toggleMode wechselt ohne Abspielunterbrechung zwischen Video und Reinaudio', () async {
      final controller = VideoModeController(
        playerOverride: mockAudioPlayer,
        videoDecoderOverride: mockVideoDecoder,
        pipControllerOverride: pipController,
      );
      controller.build();

      controller.setMediaStreams(
        audioUrl: 'https://youtube.com/audio.opus',
        videoUrl: 'https://youtube.com/video.mp4',
      );

      // Simuliere Abspielposition 42s im Audioplayer
      await controller.seek(const Duration(seconds: 42));

      // 1. Wechsel zu Video
      await controller.toggleMode();

      expect(controller.state.mode, PlaybackPresentationMode.video);
      expect(controller.state.isDecoderAllocated, isTrue);
      expect(mockVideoDecoder.isAllocated, isTrue);
      expect(mockVideoDecoder.initializeCount, 1);
      expect(mockVideoDecoder.lastInitialPos, const Duration(seconds: 42));
      expect(mockAudioPlayer.pauseCount, 1);

      // 2. Wechsel zurueck zu Reinaudio
      await controller.seek(const Duration(seconds: 85));
      await controller.toggleMode();

      expect(controller.state.mode, PlaybackPresentationMode.audioOnly);
      expect(controller.state.isDecoderAllocated, isFalse);
      expect(mockVideoDecoder.isAllocated, isFalse);
      expect(mockVideoDecoder.releaseCount, 1); // Vollstaendig freigegeben
      expect(mockAudioPlayer.lastInitialPos, const Duration(seconds: 85));
    });

    test('onAppBackgrounded aktiviert automatisch PiP im Videomodus', () async {
      final controller = VideoModeController(
        playerOverride: mockAudioPlayer,
        videoDecoderOverride: mockVideoDecoder,
        pipControllerOverride: pipController,
      );
      controller.build();

      controller.setMediaStreams(
        audioUrl: 'https://youtube.com/audio.opus',
        videoUrl: 'https://youtube.com/video.mp4',
      );

      await controller.switchToVideo();
      expect(controller.state.isVideo, isTrue);

      final enteredPip = await controller.onAppBackgrounded();
      expect(enteredPip, isTrue);
      expect(mockPipBridge.enterPipCount, 1);
    });

    test('Beim Ausschalten des Bildschirms wird sofort in den Reinaudio-Modus gewechselt', () async {
      final controller = VideoModeController(
        playerOverride: mockAudioPlayer,
        videoDecoderOverride: mockVideoDecoder,
        pipControllerOverride: pipController,
      );
      controller.build();

      controller.setMediaStreams(
        audioUrl: 'https://youtube.com/audio.opus',
        videoUrl: 'https://youtube.com/video.mp4',
      );

      await controller.switchToVideo();
      expect(controller.state.isVideo, isTrue);
      expect(controller.state.isDecoderAllocated, isTrue);

      // Simuliere Bildschirm-Ausschaltung (Screen Off)
      mockPipBridge.emitScreen(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.mode, PlaybackPresentationMode.audioOnly);
      expect(controller.state.isDecoderAllocated, isFalse);
      expect(mockVideoDecoder.isAllocated, isFalse);
    });
  });
}
