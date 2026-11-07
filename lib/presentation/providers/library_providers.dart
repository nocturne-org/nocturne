import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../../domain/usecases/import_folder_usecase.dart';
import '../controllers/library_browser_controller.dart';
import '../state/library_browser_state.dart';
import 'audio_providers.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Provider for the LibraryBrowserController.
final libraryBrowserControllerProvider =
    NotifierProvider<LibraryBrowserController, LibraryBrowserState>(
  LibraryBrowserController.new,
);

/// Provider for the recursive folder import use case with SQLite auto-playlist
/// and optional immediate playback.
final importFolderUseCaseProvider = Provider<ImportFolderUseCase>((ref) {
  final mediaDao = ref.watch(mediaDaoProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  AudioPlayerRepository? player;
  try {
    player = ref.watch(audioPlayerRepositoryProvider);
  } catch (_) {
    // Graceful fallback if audio player is not overridden in test environment
  }
  return ImportFolderUseCase(
    mediaRepository: repo,
    mediaDao: mediaDao,
    audioPlayer: player,
  );
});
