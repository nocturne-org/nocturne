/// Darstellungsmodus fuer Medieninhalte mit Video- und Audiostreams.
enum PlaybackPresentationMode {
  audioOnly,
  video,
}

/// Unveraenderlicher Zustand fuer den Video/Audio Umschalter und PiP-Modus.
class VideoPlaybackState {
  const VideoPlaybackState({
    this.mode = PlaybackPresentationMode.audioOnly,
    this.isPipActive = false,
    this.isVideoAvailable = false,
    this.videoUrl,
    this.audioUrl,
    this.isDecoderAllocated = false,
    this.isScreenOn = true,
    this.currentPosition = Duration.zero,
    this.isPlaying = false,
  });

  /// Aktueller Wiedergabemodus (Reinaudio oder Video).
  final PlaybackPresentationMode mode;

  /// Ob Picture-in-Picture aktuell aktiv ist.
  final bool isPipActive;

  /// Ob ein gueltiger Videostream fuer das aktuelle Medium vorliegt.
  final bool isVideoAvailable;

  /// HTTP-URL des Videostreams.
  final String? videoUrl;

  /// HTTP-URL des Audiostreams.
  final String? audioUrl;

  /// Ob Hardware-Videodecoder aktuell im Speicher allokiert ist.
  /// Muss im Modus audioOnly zwingend false sein (0 GPU-/Decoder-Last).
  final bool isDecoderAllocated;

  /// Ob der Geraetebildschirm eingeschaltet ist.
  final bool isScreenOn;

  /// Aktuelle synchrone Abspielposition.
  final Duration currentPosition;

  /// Ob die Wiedergabe aktiv laeuft.
  final bool isPlaying;

  /// Ob reines Audio abgespielt wird.
  bool get isAudioOnly => mode == PlaybackPresentationMode.audioOnly;

  /// Ob Video abgespielt wird.
  bool get isVideo => mode == PlaybackPresentationMode.video;

  VideoPlaybackState copyWith({
    PlaybackPresentationMode? mode,
    bool? isPipActive,
    bool? isVideoAvailable,
    String? videoUrl,
    String? audioUrl,
    bool? isDecoderAllocated,
    bool? isScreenOn,
    Duration? currentPosition,
    bool? isPlaying,
  }) {
    return VideoPlaybackState(
      mode: mode ?? this.mode,
      isPipActive: isPipActive ?? this.isPipActive,
      isVideoAvailable: isVideoAvailable ?? this.isVideoAvailable,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      isDecoderAllocated: isDecoderAllocated ?? this.isDecoderAllocated,
      isScreenOn: isScreenOn ?? this.isScreenOn,
      currentPosition: currentPosition ?? this.currentPosition,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  String toString() =>
      'VideoPlaybackState(mode: $mode, pip: $isPipActive, decoder: $isDecoderAllocated, pos: ${currentPosition.inSeconds}s)';
}
