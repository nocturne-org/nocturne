import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/media_repository.dart';
import '../../domain/models/media_item.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../providers/audio_providers.dart';
import '../providers/repository_providers.dart';
import '../state/unified_queue_state.dart';

/// Zentraler Controller fuer die einheitliche Abspiel-Warteschlange (Unified Playback Queue).
/// Ermoeglicht das nahtlose Mischen von Audiobuechern, Podcast-Episoden und YouTube-Audioquellen,
/// automatisches Fortschalten bei Trackende, Drag-and-Drop Reordering, Wisch-Loeschen
/// und vollstaendige Drift-Datenbank-Persistenz.
class UnifiedQueueController extends Notifier<UnifiedQueueState> {
  UnifiedQueueController({
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

  @override
  UnifiedQueueState build() {
    _initSubscriptions();
    ref.onDispose(_cleanup);

    // Initialen Zustand laden
    Future.microtask(() => loadPersistedQueue());

    return const UnifiedQueueState();
  }

  void _initSubscriptions() {
    _statusSub = _player.playbackStatusStream.listen((status) {
      if (status == AudioPlaybackStatus.completed) {
        _onTrackCompleted();
      }
    });
  }

  void _cleanup() {
    _statusSub?.cancel();
    _statusSub = null;
  }

  /// Laedt die persistent in der Drift-Datenbank gespeicherte Queue.
  Future<void> loadPersistedQueue() async {
    if (state.items.isNotEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final queueIds = await _mediaRepo.loadPlaybackQueue();
      final currentIndex = await _mediaRepo.loadPlaybackQueueCurrentIndex();

      if (queueIds.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          items: state.items.isEmpty ? const [] : state.items,
        );
        return;
      }

      final loadedItems = <MediaItem>[];
      for (final id in queueIds) {
        final item = await _mediaRepo.getMediaById(id);
        if (item != null) {
          loadedItems.add(item);
        }
      }

      final safeIndex = (currentIndex >= 0 && currentIndex < loadedItems.length)
          ? currentIndex
          : 0;

      state = state.copyWith(
        items: loadedItems,
        currentIndex: safeIndex,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Reiht einen neuen Titel am Ende der Queue ein.
  Future<void> addItem(MediaItem item) async {
    final wasEmpty = state.items.isEmpty;
    final newItems = List<MediaItem>.from(state.items)..add(item);

    state = state.copyWith(items: newItems);
    await _persistQueue();

    if (wasEmpty) {
      await playTrackAtIndex(0);
    }
  }

  /// Reiht mehrere Titel am Ende der Queue ein.
  Future<void> addItems(List<MediaItem> items) async {
    if (items.isEmpty) return;
    final wasEmpty = state.items.isEmpty;
    final newItems = List<MediaItem>.from(state.items)..addAll(items);

    state = state.copyWith(items: newItems);
    await _persistQueue();

    if (wasEmpty) {
      await playTrackAtIndex(0);
    }
  }

  /// Fuegt einen Titel als naechsten Track direkt hinter dem aktuellen Titel ein.
  Future<void> insertNext(MediaItem item) async {
    if (state.items.isEmpty) {
      await addItem(item);
      return;
    }

    final newItems = List<MediaItem>.from(state.items);
    final insertIndex = state.currentIndex + 1;
    newItems.insert(insertIndex, item);

    state = state.copyWith(items: newItems);
    await _persistQueue();
  }

  /// Entfernt einen Titel anhand seines Index (z. B. nach Wischgeste).
  Future<void> removeItem(int index) async {
    if (index < 0 || index >= state.items.length) return;

    final newItems = List<MediaItem>.from(state.items);
    newItems.removeAt(index);

    if (newItems.isEmpty) {
      state = state.copyWith(items: const [], currentIndex: 0);
      await _player.stop();
      await _mediaRepo.clearPlaybackQueue();
      return;
    }

    var newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex -= 1;
    } else if (index == state.currentIndex) {
      if (newIndex >= newItems.length) {
        newIndex = newItems.length - 1;
      }
      // Neuer Titel an aktueller Position muss geladen werden
      state = state.copyWith(items: newItems, currentIndex: newIndex);
      await _persistQueue();
      await playTrackAtIndex(newIndex);
      return;
    }

    state = state.copyWith(items: newItems, currentIndex: newIndex);
    await _persistQueue();
  }

  /// Reordering per Drag-and-Drop in der Benutzeroberflaeche.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.items.length) return;

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= state.items.length) return;
    if (oldIndex == targetIndex) return;

    final newItems = List<MediaItem>.from(state.items);
    final movedItem = newItems.removeAt(oldIndex);
    newItems.insert(targetIndex, movedItem);

    // Berechne neuen Index des aktuell aktiven Tracks
    var updatedCurrentIndex = state.currentIndex;
    if (state.currentIndex == oldIndex) {
      updatedCurrentIndex = targetIndex;
    } else if (oldIndex < state.currentIndex &&
        targetIndex >= state.currentIndex) {
      updatedCurrentIndex -= 1;
    } else if (oldIndex > state.currentIndex &&
        targetIndex <= state.currentIndex) {
      updatedCurrentIndex += 1;
    }

    state = state.copyWith(
      items: newItems,
      currentIndex: updatedCurrentIndex,
    );

    await _persistQueue();
  }

  /// Spielt den Titel am gewuenschten Index ab.
  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= state.items.length) return;

    final targetItem = state.items[index];
    state = state.copyWith(currentIndex: index);
    await _persistQueue();

    await _player.setSource(targetItem.source);
    await _player.play();
  }

  /// Unterbrechungsfreier Uebergang zum naechsten Track.
  Future<void> skipToNext() async {
    if (state.items.isEmpty) return;

    if (state.currentIndex < state.items.length - 1) {
      await playTrackAtIndex(state.currentIndex + 1);
    } else if (state.repeatMode == QueueRepeatMode.all) {
      await playTrackAtIndex(0);
    }
  }

  /// Zurueck zum vorherigen Track.
  Future<void> skipToPrevious() async {
    if (state.items.isEmpty) return;

    if (state.currentIndex > 0) {
      await playTrackAtIndex(state.currentIndex - 1);
    } else if (state.repeatMode == QueueRepeatMode.all) {
      await playTrackAtIndex(state.items.length - 1);
    }
  }

  /// Aendert den Wiederholungsmodus.
  void setRepeatMode(QueueRepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
  }

  /// Schaltet den Shuffle-Zustand um.
  void toggleShuffle() {
    state = state.copyWith(isShuffleEnabled: !state.isShuffleEnabled);
  }

  /// Leert die gesamte Warteschlange.
  Future<void> clearQueue() async {
    state = state.copyWith(items: const [], currentIndex: 0);
    await _player.stop();
    await _mediaRepo.clearPlaybackQueue();
  }

  Future<void> _onTrackCompleted() async {
    if (state.repeatMode == QueueRepeatMode.single) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (state.hasNext) {
      await skipToNext();
    } else {
      await _player.stop();
    }
  }

  Future<void> _persistQueue() async {
    try {
      final ids = state.items.map((i) => i.id).toList();
      await _mediaRepo.savePlaybackQueue(
        ids,
        currentIndex: state.currentIndex,
      );
    } catch (_) {
      // Fehler beim Persistieren faengt den App-Ablauf nicht ab
    }
  }
}
