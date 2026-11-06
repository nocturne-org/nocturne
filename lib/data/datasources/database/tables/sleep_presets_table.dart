import 'package:drift/drift.dart';

/// Drift-Tabellendefinition fuer Sleep-Timer Profile und Voreinstellungen.
class SleepPresetsTable extends Table {
  @override
  String get tableName => 'sleep_presets';

  /// Eindeutige Kennung des Presets.
  TextColumn get id => text()();

  /// Anzeigename des Voreinstellungsprofils (z. B. "Einschlafen 30m").
  TextColumn get name => text()();

  /// Dauer des Sleep-Timers in Minuten.
  IntColumn get durationMinutes => integer()();

  /// Dauer des sanften Lautstaerke-Fade-Outs in Sekunden (Standard: 60s).
  IntColumn get autoFadeOutSeconds =>
      integer().withDefault(const Constant(60))();

  /// Dauer der Shake-Grace-Period in Sekunden (Standard: 120s).
  IntColumn get shakeGracePeriodSeconds =>
      integer().withDefault(const Constant(120))();

  /// Automatischer Rueckspul-Wert in Sekunden (Standard: 45s).
  IntColumn get autoRewindSeconds =>
      integer().withDefault(const Constant(45))();

  /// Kennzeichnung als Standard-Profil.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
