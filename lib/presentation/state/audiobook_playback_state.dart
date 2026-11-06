import '../../domain/models/chapter.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/playback_position.dart';
import '../../domain/repositories/audio_player_repository.dart';

/// Unveraenderlicher Zustand des Hoerbuch-Players.
class AudiobookPlaybackState {
  const AudiobookPlaybackState({
    this.currentMedia,
    this.currentTrackIndex = 0,
    this.tracks = const [],
    this.status = AudioPlaybackStatus.idle,
    this.position = PlaybackPosition.zero,
    this.totalDuration = Duration.zero,
    this.currentChapter,
    this.chapters = const [],
    this.lastSavedPosition = PlaybackPosition.zero,
  });

  /// Das aktuell geladene Medium.
  final MediaItem? currentMedia;

  /// Index des aktuellen Tracks bei Multi-Track Hoerbuechern (0-basiert).
  final int currentTrackIndex;

  /// Liste aller Tracks des aktuellen Hoerbuchs.
  final List<MediaItem> tracks;

  /// Wiedergabestatus des Audio-Treibers.
  final AudioPlaybackStatus status;

  /// Exakte Abspielposition.
  final PlaybackPosition position;

  /// Gesamtdauer des aktuellen Tracks oder Mediums.
  final Duration totalDuration;

  /// Aktives Kapitel (falls vorhanden).
  final Chapter? currentChapter;

  /// Liste aller verfuegbaren Kapitelmarken.
  final List<Chapter> chapters;

  /// Zuletzt in der Datenbank gespeicherte Position.
  final PlaybackPosition lastSavedPosition;

  /// Ob aktuell Audio abgespielt wird.
  bool get isPlaying => status == AudioPlaybackStatus.playing;

  /// Ob es sich um ein Multi-Track Hoerbuch handelt.
  bool get isMultiTrack => tracks.length > 1;

  AudiobookPlaybackState copyWith({
    MediaItem? currentMedia,
    int? currentTrackIndex,
    List<MediaItem>? tracks,
    AudioPlaybackStatus? status,
    PlaybackPosition? position,
    Duration? totalDuration,
    Chapter? currentChapter,
    List<Chapter>? chapters,
    PlaybackPosition? lastSavedPosition,
  }) {
    return AudiobookPlaybackState(
      currentMedia: currentMedia ?? this.currentMedia,
      currentTrackIndex: currentTrackIndex ?? this.currentTrackIndex,
      tracks: tracks ?? this.tracks,
      status: status ?? this.status,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      currentChapter: currentChapter ?? this.currentChapter,
      chapters: chapters ?? this.chapters,
      lastSavedPosition: lastSavedPosition ?? this.lastSavedPosition,
    );
  }

  @override
  String toString() =>
      'AudiobookPlaybackState(title: "${currentMedia?.title}", status: $status, pos: ${position.formatProgress()}, chap: "${currentChapter?.title}")';
}
