# 007: Android Storage Access Framework (SAF) Ordner-Picker & Permissions

**What to build:**
Integration des Android Storage Access Frameworks (SAF) zur Auswahl externer Hoerbuch-Verzeichnisse mit persistierten Rechten ueber Neustarts.

**Blocked by:**
Keine (Start sofort)

**Phase:** Phase 2: Local Storage & Library
**Type:** Feature | **Layer:** Platform / Storage | **Points:** 3 | **Priority:** P1
**Status:** completed

**Acceptance criteria:**
- [x] Nutzer kann beliebige Ordner auf internem Speicher oder SD-Karte auswaehlen.
- [x] App fordert und speichert takePersistableUriPermission dauerhaft.
- [x] Verzeichnis-Berechtigungen bleiben nach Geraeteneustart vollstaendig erhalten.
- [x] Fehlertolerante Rueckmeldung, wenn SD-Karte entfernt oder Pfad geloescht wurde.

**Verification method:**
Manual Verification & SAF Integration
