import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/domain/models/audio/audio_source_ref.dart';
import 'package:nocturne/domain/models/media_item.dart' as domain;
import 'package:nocturne/domain/models/playback_position.dart';
import 'package:nocturne/platform/audio/media_session_service_adapter.dart';
import 'package:nocturne/platform/audio/nocturne_audio_handler.dart';

void main() {
  group('NocturneAudioHandler Tests (TICK-005)', () {
    late NocturneAudioHandler handler;
    var playCalled = false;
    var pauseCalled = false;
    var stopCalled = false;
    Duration? seekPositionCalled;

    setUp(() {
      playCalled = false;
      pauseCalled = false;
      stopCalled = false;
      seekPositionCalled = null;

      handler = NocturneAudioHandler(
        onPlayCallback: () async {
          playCalled = true;
        },
        onPauseCallback: () async {
          pauseCalled = true;
        },
        onStopCallback: () async {
          stopCalled = true;
        },
        onSeekCallback: (pos) async {
          seekPositionCalled = pos;
        },
      );
    });

    test('Initialer Status ist idle mit korrekten Standard-Werten', () async {
      final state = await handler.playbackState.first;
      expect(state.playing, isFalse);
      expect(state.processingState, audio_service.AudioProcessingState.idle);
      expect(state.updatePosition, Duration.zero);
      expect(state.androidCompactActionIndices, [0, 1, 2]);
    });

    test('updateMediaItemFromDomain uebertraegt Metadaten vollstaendig', () async {
      const domainItem = domain.MediaItem(
        id: 'item-1',
        title: 'Schlaf-Meditation Teil 1',
        type: domain.MediaType.audiobook,
        source: AudioSourceRef.file('/data/audio.mp3'),
        author: 'Dr. Nachtigall',
        album: 'Besser Einschlafen',
        duration: Duration(minutes: 45),
        coverArtUri: 'https://example.com/cover.jpg',
        lastPosition: PlaybackPosition(duration: Duration(minutes: 5)),
      );

      handler.updateMediaItemFromDomain(domainItem);

      final serviceItem = await handler.mediaItem.first;
      expect(serviceItem?.id, 'item-1');
      expect(serviceItem?.title, 'Schlaf-Meditation Teil 1');
      expect(serviceItem?.artist, 'Dr. Nachtigall');
      expect(serviceItem?.album, 'Besser Einschlafen');
      expect(serviceItem?.duration, const Duration(minutes: 45));
      expect(serviceItem?.artUri, Uri.parse('https://example.com/cover.jpg'));

      final state = await handler.playbackState.first;
      expect(state.updatePosition, const Duration(minutes: 5));
    });

    test('play und pause aktualisieren State und loesen Callbacks aus', () async {
      await handler.play();
      expect(playCalled, isTrue);

      var state = await handler.playbackState.first;
      expect(state.playing, isTrue);
      expect(state.processingState, audio_service.AudioProcessingState.ready);

      await handler.pause();
      expect(pauseCalled, isTrue);

      state = await handler.playbackState.first;
      expect(state.playing, isFalse);
    });

    test('fastForward und rewind spulen exakt 15 Sekunden', () async {
      // Setze initiale Position auf 30 Sekunden
      await handler.seek(const Duration(seconds: 30));

      await handler.fastForward();
      expect(seekPositionCalled, const Duration(seconds: 45));

      var state = await handler.playbackState.first;
      expect(state.updatePosition, const Duration(seconds: 45));

      await handler.rewind();
      expect(seekPositionCalled, const Duration(seconds: 30));

      state = await handler.playbackState.first;
      expect(state.updatePosition, const Duration(seconds: 30));

      // Rewind unter 0 wird auf Duration.zero geklammert
      await handler.seek(const Duration(seconds: 5));
      await handler.rewind();
      expect(seekPositionCalled, Duration.zero);
    });

    test('click verarbeitet Headset- und Bluetooth-Tasten korrekt', () async {
      // Standard MediaButton toggelt Play/Pause
      expect(handler.playbackState.value.playing, isFalse);
      await handler.click(audio_service.MediaButton.media);
      expect(handler.playbackState.value.playing, isTrue);

      await handler.click(audio_service.MediaButton.media);
      expect(handler.playbackState.value.playing, isFalse);

      // Next fuehrt FastForward aus
      await handler.seek(const Duration(seconds: 10));
      await handler.click(audio_service.MediaButton.next);
      expect(handler.playbackState.value.updatePosition, const Duration(seconds: 25));

      // Previous fuehrt Rewind aus
      await handler.click(audio_service.MediaButton.previous);
      expect(handler.playbackState.value.updatePosition, const Duration(seconds: 10));
    });

    test('stop setzt Position und Status sauber zurueck', () async {
      await handler.play();
      await handler.seek(const Duration(minutes: 10));

      await handler.stop();
      expect(stopCalled, isTrue);

      final state = await handler.playbackState.first;
      expect(state.playing, isFalse);
      expect(state.processingState, audio_service.AudioProcessingState.idle);
      expect(state.updatePosition, Duration.zero);
    });

    test('MediaSessionServiceAdapter stellt korrekte Notification-Werte bereit', () {
      expect(
        MediaSessionServiceAdapter.notificationChannelId,
        'com.nocturne.audio.channel',
      );
      expect(
        MediaSessionServiceAdapter.notificationChannelName,
        'Nocturne Bedtime Audio',
      );
    });
  });
}
