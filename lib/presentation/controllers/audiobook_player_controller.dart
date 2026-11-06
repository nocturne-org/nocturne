import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/media_repository.dart';
import '../../domain/models/chapter.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../providers/audio_providers.dart';
import '../providers/repository_providers.dart';
import '../state/audiobook_playback_state.dart';

/// Zentraler Controller fuer die Wiedergabe lokaler Hoerbuecher.
/// Verwaltet Track-Uebergaenge, Kapitelsprung, periodische Lesezeichen-Speicherung (alle 5s)
/// und nahtlosen Auto-Resume nach Neustarts.
class AudiobookPlayerController extends Notifier<AudiobookPlaybackState> {
  AudiobookPlayerController({
    AudioPlayerRepository? playerOverride,
    MediaRepository? mediaRepoOverride,
  })  : _playerOverride = playerOverride,
        _mediaRepoOverride = mediaRepoOverride;

  final AudioPlayerRepository? _playerOverride;
  final MediaRepository? _mediaRepoOverride;

  AudioPlayerRepository get _player =>
      _playerOverride ?? ref.read(audioPlayerRepositoryProvider);

  MediaRepository get _mediaRepo =>
      _mediaRepoOverride ?? ref.read(mediaRepositoryProvider);

  StreamSubscription<AudioPlaybackStatus>? _statusSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  AudiobookPlaybackState build() {
    _initSubscriptions();
    ref.onDispose(_cleanup);
    return const AudiobookPlaybackState();
  }

  void _initSubscriptions() {
    _statusSub = _player.playbackStatusStream.listen((status) {
      state = state.copyWith(status: status);
      if (status == AudioPlaybackStatus.completed) {
        _onTrackCompleted();
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      _onPositionChanged(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(totalDuration: dur);
      }
    });
  }

  void _cleanup() {
    _statusSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    // Letzte Position bei Dispose sichern
    _saveCurrentPosition();
  }

  /// Laedt ein einzelnes Hoerbuch (z. B. M4B) und startet die Wiedergabe.
  /// [autoResume]: Springt an die zuletzt in der Datenbank gespeicherte Position.
  Future<void> loadAndPlay(
    MediaItem media, {
    bool autoResume = true,
  }) async {
    final startPos = autoResume && media.lastPosition.isValid
        ? media.lastPosition.duration
        : Duration.zero;

    state = state.copyWith(
      currentMedia: media,
      currentTrackIndex: 0,
      tracks: [media],
      chapters: media.chapters,
      position: PlaybackPosition(duration: startPos),
      lastSavedPosition: PlaybackPosition(duration: startPos),
      currentChapter: media.getChapterAt(PlaybackPosition(duration: startPos)),
    );

    await _player.setSource(media.source, initialPosition: startPos);
    await _player.play();
  }

  /// Laedt ein mehrteiliges Hoerbuch (Multi-Track) mit geordneten Tracks.
  Future<void> loadMultiTrack(
    List<MediaItem> tracks, {
    int initialTrackIndex = 0,
    bool autoResume = true,
  }) async {
    if (tracks.isEmpty) return;

    final index = initialTrackIndex.clamp(0, tracks.length - 1);
    final media = tracks[index];

    final startPos = autoResume && media.lastPosition.isValid
        ? media.lastPosition.duration
        : Duration.zero;

    state = state.copyWith(
      currentMedia: media,
      currentTrackIndex: index,
      tracks: tracks,
      chapters: media.chapters,
      position: PlaybackPosition(duration: startPos),
      lastSavedPosition: PlaybackPosition(duration: startPos),
      currentChapter: media.getChapterAt(PlaybackPosition(duration: startPos)),
    );

    await _player.setSource(media.source, initialPosition: startPos);
    await _player.play();
  }

  /// Startet oder setzt die Wiedergabe fort.
  Future<void> play() async {
    await _player.play();
  }

  /// Pausiert die Wiedergabe und speichert sofort die aktuelle Abspielposition.
  Future<void> pause() async {
    await _player.pause();
    await _saveCurrentPosition();
  }

  /// Springt an eine bestimmte Zeitposition im aktuellen Track.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final playPos = PlaybackPosition(duration: position);
    state = state.copyWith(
      position: playPos,
      currentChapter: state.currentMedia?.getChapterAt(playPos),
    );
    await _saveCurrentPosition();
  }

  /// Springt direkt an den Beginn eines Kapitels.
  Future<void> seekToChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    final chapter = state.chapters[chapterIndex];
    await seek(chapter.start);
    state = state.copyWith(currentChapter: chapter);
  }

  /// Springt zum naechsten Track in der Multi-Track-Liste.
  Future<void> nextTrack() async {
    if (!state.isMultiTrack) return;
    final nextIndex = state.currentTrackIndex + 1;
    if (nextIndex < state.tracks.length) {
      await _saveCurrentPosition(isCompleted: true);
      await loadMultiTrack(state.tracks, initialTrackIndex: nextIndex, autoResume: false);
    }
  }

  /// Springt zum vorherigen Track in der Multi-Track-Liste.
  Future<void> previousTrack() async {
    if (!state.isMultiTrack) return;
    final prevIndex = state.currentTrackIndex - 1;
    if (prevIndex >= 0) {
      await _saveCurrentPosition();
      await loadMultiTrack(state.tracks, initialTrackIndex: prevIndex, autoResume: false);
    }
  }

  void _onPositionChanged(Duration pos) {
    final playPos = PlaybackPosition(duration: pos);
    final activeChap = state.currentMedia?.getChapterAt(playPos);

    state = state.copyWith(
      position: playPos,
      currentChapter: activeChap ?? state.currentChapter,
    );

    // Automatisches Lesezeichen alle 5 Sekunden (5000 ms)
    final diffMs = (pos.inMilliseconds - state.lastSavedPosition.milliseconds).abs();
    if (diffMs >= 5000) {
      _saveCurrentPosition();
    }
  }

  void _onTrackCompleted() {
    _saveCurrentPosition(isCompleted: true);
    if (state.isMultiTrack && state.currentTrackIndex + 1 < state.tracks.length) {
      nextTrack();
    }
  }

  Future<void> _saveCurrentPosition({bool? isCompleted}) async {
    final media = state.currentMedia;
    if (media == null) return;

    final pos = state.position;
    state = state.copyWith(lastSavedPosition: pos);

    try {
      await _mediaRepo.updatePosition(
        media.id,
        pos,
        isCompleted: isCompleted,
        lastPlayedAt: DateTime.now(),
      );
    } catch (_) {
      // Fehlertolerante Lesezeichen-Speicherung
    }
  }
}

/// Provider fuer den [AudiobookPlayerController].
final audiobookPlayerControllerProvider =
    NotifierProvider<AudiobookPlayerController, AudiobookPlaybackState>(
  AudiobookPlayerController.new,
);
