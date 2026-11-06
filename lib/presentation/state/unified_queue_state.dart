import '../../domain/models/media_item.dart';

/// Wiederholungsmodi fuer die Abspiel-Warteschlange.
enum QueueRepeatMode {
  off,
  all,
  single,
}

/// Unveraenderlicher Zustand der einheitlichen Abspiel-Warteschlange (Unified Playback Queue).
class UnifiedQueueState {
  const UnifiedQueueState({
    this.items = const [],
    this.currentIndex = 0,
    this.repeatMode = QueueRepeatMode.off,
    this.isShuffleEnabled = false,
    this.isLoading = false,
  });

  /// Alle Titel in der aktuellen Reihenfolge (Audiobuecher, Podcasts, YouTube).
  final List<MediaItem> items;

  /// Index des aktuell wiedergegebenen Titels.
  final int currentIndex;

  /// Wiederholungsmodus.
  final QueueRepeatMode repeatMode;

  /// Ob Shuffle aktiv ist.
  final bool isShuffleEnabled;

  /// Ob die Queue gerade initialisiert oder synchronisiert wird.
  final bool isLoading;

  /// Aktuell aktives Medium oder null, falls Queue leer ist.
  MediaItem? get currentItem {
    if (items.isEmpty || currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  /// Ob ein naechster Titel verfuegbar ist.
  bool get hasNext {
    if (items.isEmpty) return false;
    if (repeatMode == QueueRepeatMode.all) return true;
    return currentIndex < items.length - 1;
  }

  /// Ob ein vorheriger Titel verfuegbar ist.
  bool get hasPrevious {
    if (items.isEmpty) return false;
    if (repeatMode == QueueRepeatMode.all) return true;
    return currentIndex > 0;
  }

  /// Gesamtanzahl der Titel in der Queue.
  int get totalTracks => items.length;

  /// Kumulierte Gesamtdauer aller Titel in der Warteschlange in Millisekunden.
  int get totalDurationMs {
    return items.fold<int>(0, (sum, item) => sum + (item.durationMs ?? 0));
  }

  UnifiedQueueState copyWith({
    List<MediaItem>? items,
    int? currentIndex,
    QueueRepeatMode? repeatMode,
    bool? isShuffleEnabled,
    bool? isLoading,
  }) {
    return UnifiedQueueState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() =>
      'UnifiedQueueState(tracks: $totalTracks, current: $currentIndex, repeat: $repeatMode)';
}
