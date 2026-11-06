/// Ergebnis der Ausfuehrung eines Organisationsplans.
class OrganizeExecutionResult {
  const OrganizeExecutionResult({
    required this.success,
    required this.movedCount,
    required this.skippedCount,
    required this.rolledBackCount,
    this.errorMessage,
  });

  /// Status, ob die Organisation fehlerfrei abgeschlossen wurde.
  final bool success;

  /// Anzahl erfolgreich verschobener Dateien.
  final int movedCount;

  /// Anzahl uebersprungener Dateien (bereits organisiert oder Duplikate).
  final int skippedCount;

  /// Anzahl bei Fehlern erfolgreich zurueckgerollter Dateien.
  final int rolledBackCount;

  /// Optionale Fehlermeldung bei Rollback.
  final String? errorMessage;

  @override
  String toString() =>
      'OrganizeExecutionResult(success: $success, moved: $movedCount, skipped: $skippedCount, rolledBack: $rolledBackCount)';
}
