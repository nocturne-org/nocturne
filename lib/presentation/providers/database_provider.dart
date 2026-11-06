import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/database/app_database.dart';

/// Provider fuer die zentrale Drift SQLite-Datenbank.
/// Kann in Tests sauber durch [AppDatabase.memory()] ueberschrieben werden.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});
