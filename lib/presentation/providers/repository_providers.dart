import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/media_repository_impl.dart';
import 'database_provider.dart';

/// Provider fuer das [MediaRepository].
/// Entkoppelt die Datenhaltung von UI-Komponenten gemaess Clean Architecture.
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MediaRepositoryImpl(db: db);
});
