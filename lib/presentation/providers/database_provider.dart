import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/database/app_database.dart';
import '../../data/datasources/database/daos/media_dao.dart';

/// Provider fuer die zentrale Drift SQLite-Datenbank.
/// Kann in Tests sauber durch [AppDatabase.memory()] ueberschrieben werden.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

/// Provider fuer das MediaDao.
final mediaDaoProvider = Provider<MediaDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.mediaDao;
});

/// Reaktiver Provider fuer die Menge aller favorisierten Media-IDs.
final favoritesProvider = StreamProvider<Set<String>>((ref) {
  final dao = ref.watch(mediaDaoProvider);
  return dao.watchFavorites();
});
