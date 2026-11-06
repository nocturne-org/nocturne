/// Basisklasse fuer alle Storage Access Framework Fehler.
abstract class SafStorageException implements Exception {
  const SafStorageException(this.message, {this.treeUri, this.cause});

  /// Fehlerbeschreibung.
  final String message;

  /// Betroffener SAF Tree-URI (sofern bekannt).
  final String? treeUri;

  /// Urspruengliche Ausnahmeursache (falls vorhanden).
  final Object? cause;

  @override
  String toString() {
    final uriInfo = treeUri != null ? ' [URI: $treeUri]' : '';
    final causeInfo = cause != null ? ' (Ursache: $cause)' : '';
    return '$runtimeType: $message$uriInfo$causeInfo';
  }
}

/// Wird ausgeloest, wenn der Nutzer die Ordner-Auswahl abbricht oder Rechte verweigert.
class SafPermissionDeniedException extends SafStorageException {
  const SafPermissionDeniedException(super.message, {super.treeUri, super.cause});
}

/// Wird ausgeloest, wenn ein zuvor persistierter Ordner nicht mehr existiert.
class SafDirectoryNotFoundException extends SafStorageException {
  const SafDirectoryNotFoundException(super.message, {super.treeUri, super.cause});
}

/// Wird ausgeloest, wenn das Speichermedium (z. B. SD-Karte) entfernt oder nicht eingehaengt ist.
class SafStorageUnavailableException extends SafStorageException {
  const SafStorageUnavailableException(super.message, {super.treeUri, super.cause});
}

/// Wird ausgeloest, wenn Android die Sicherheitsberechtigung fuer den URI verworfen hat.
class SafSecurityException extends SafStorageException {
  const SafSecurityException(super.message, {super.treeUri, super.cause});
}

/// Wird ausgeloest bei Kommunikationsproblemen mit dem nativen Platform-Channel.
class SafChannelException extends SafStorageException {
  const SafChannelException(super.message, {super.treeUri, super.cause});
}
