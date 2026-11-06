import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/audio_player_repository.dart';
import 'audio_providers.dart';

/// Unveraenderlicher Zustand des Bedtime-Audio-Players.
class BedtimePlaybackState {
  final String title;
  final String author;
  final bool isPlaying;
  final Duration position;
  final Duration totalDuration;

  const BedtimePlaybackState({
    this.title = 'Nocturne Bedtime Audio',
    this.author = 'Kein Medium geladen',
    this.isPlaying = false,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
  });

  BedtimePlaybackState copyWith({
    String? title,
    String? author,
    bool? isPlaying,
    Duration? position,
    Duration? totalDuration,
  }) {
    return BedtimePlaybackState(
      title: title ?? this.title,
      author: author ?? this.author,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}

/// Controller fuer die vereinfachte Bedtime-Player-Wiedergabe (TICK-027).
class BedtimeAudioNotifier extends Notifier<BedtimePlaybackState> {
  AudioPlayerRepository get _player => ref.read(audioPlayerRepositoryProvider);

  @override
  BedtimePlaybackState build() {
    try {
      final player = ref.read(audioPlayerRepositoryProvider);
      player.playbackStatusStream.listen((status) {
        state =
            state.copyWith(isPlaying: status == AudioPlaybackStatus.playing);
      });
      player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      });
      player.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(totalDuration: dur);
        }
      });
    } catch (_) {
      // Isolierte Initialisierung
    }
    return const BedtimePlaybackState();
  }

  /// Schaltet zwischen Wiedergabe und Pause um.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Spult exakt 15 Sekunden zurueck.
  Future<void> rewind15() async {
    await seekRelative(const Duration(seconds: -15));
  }

  /// Spult exakt 15 Sekunden vor.
  Future<void> forward15() async {
    await seekRelative(const Duration(seconds: 15));
  }

  /// Spult um ein relatives Delta mit Randwertpruefung (0 bis Gesamtlaenge).
  Future<void> seekRelative(Duration delta) async {
    final cur = state.position;
    final target = cur + delta;
    if (target < Duration.zero) {
      await _player.seek(Duration.zero);
    } else if (state.totalDuration > Duration.zero && target > state.totalDuration) {
      await _player.seek(state.totalDuration);
    } else {
      await _player.seek(target);
    }
  }

  /// Spult exakt 30 Sekunden zurueck.
  Future<void> rewind30() async {
    final cur = state.position;
    final target = cur - const Duration(seconds: 30);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  /// Spult exakt 30 Sekunden vor.
  Future<void> forward30() async {
    final cur = state.position;
    await _player.seek(cur + const Duration(seconds: 30));
  }

  /// Aktualisiert den angezeigten Titel und Autor.
  void updateMetadata({required String title, required String author}) {
    state = state.copyWith(title: title, author: author);
  }
}

/// Provider fuer den Bedtime-Audio-Controller.
final bedtimeAudioProvider =
    NotifierProvider<BedtimeAudioNotifier, BedtimePlaybackState>(
  BedtimeAudioNotifier.new,
);
