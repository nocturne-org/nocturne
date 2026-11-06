import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/audio_player_repository.dart';

/// Provider fuer den platform-unabhaengigen [AudioPlayerRepository].
/// Wird in Produktionsumgebungen durch die konkrete Plattform-Implementierung
/// und in Widget-/Unit-Tests durch Test-Mocks ueberschrieben (Dependency Injection).
final audioPlayerRepositoryProvider = Provider<AudioPlayerRepository>((ref) {
  throw UnimplementedError(
    'audioPlayerRepositoryProvider muss in ProviderScope ueberschrieben werden.',
  );
});
