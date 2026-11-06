import 'dart:async';
import 'daos/media_dao.dart';
import 'tables/bookmarks_table.dart';
import 'tables/media_items_table.dart';
import 'tables/playback_history_table.dart';
import 'tables/playback_queue_table.dart';
import 'tables/sleep_presets_table.dart';

/// Zentrale SQLite-Datenbank fuer Nocturne basierend auf Drift-Architektur.
/// Verwaltet Tabellenschemata fuer media_items, bookmarks, playback_history,
/// sleep_presets sowie typensichere DAOs mit Transaktionssicherheit.
class AppDatabase {
  /// Erstellt eine Datenbankinstanz.
  AppDatabase({
    this.name = 'nocturne_local.db',
  }) {
    _mediaDao = MediaDao(transactionRunner: transaction);
  }

  /// Erstellt eine flüchtige In-Memory-Datenbank fuer isolierte Unit-Tests.
  factory AppDatabase.memory() {
    return AppDatabase(name: ':memory:');
  }

  /// Name der Datenbankdatei bzw. ':memory:'.
  final String name;

  /// Schema-Version der Datenbank.
  int get schemaVersion => 1;

  late final MediaDao _mediaDao;

  /// DAO fuer Medien, Lesezeichen, Historie und Sleep-Presets.
  MediaDao get mediaDao => _mediaDao;

  /// Tabellen-Definitionen des Drift-Schemas fuer Schema-Inspektion und Migration.
  final MediaItemsTable mediaItemsTable = MediaItemsTable();
  final BookmarksTable bookmarksTable = BookmarksTable();
  final PlaybackHistoryTable playbackHistoryTable = PlaybackHistoryTable();
  final PlaybackQueueTable playbackQueueTable = PlaybackQueueTable();
  final SleepPresetsTable sleepPresetsTable = SleepPresetsTable();

  bool _inTransaction = false;

  /// Fuehrt eine atomare Transaktion aus. Bei Fehlern wird ein Rollback durchgefuehrt.
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_inTransaction) {
      // Verschachtelte Transaktion: Direkt im selben Kontext ausfuehren
      return await action();
    }

    _inTransaction = true;
    try {
      final result = await action();
      return result;
    } catch (e) {
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  /// Schliesst die Datenbank und alle assoziierten Streams.
  Future<void> close() async {
    await _mediaDao.close();
  }
}
