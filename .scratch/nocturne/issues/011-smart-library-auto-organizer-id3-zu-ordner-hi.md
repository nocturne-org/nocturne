# 011: Smart Library Auto-Organizer (ID3 zu Ordner-Hierarchie)

**What to build:**
Automatisches Sortier- und Verschiebe-Werkzeug nach dem Schema: Autor / Buchname / Track - Titel.ext inklusive Duplikaterkennung.

**Blocked by:**
TICK-010

**Phase:** Phase 2: Local Storage & Library
**Type:** Feature | **Layer:** Domain & Storage | **Points:** 5 | **Priority:** P2
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Erkennt unstrukturierte oder falsch abgelegte Audiodateien in Zielordnern.
- [ ] Vorschau-Modus (Dry-Run): Zeigt geplante Aenderungen vor Ausfuehrung.
- [ ] Atomare Verschiebung mit Rollback-Sicherheit bei Dateisystem-Fehlern.
- [ ] Sanitisierung von Sonderzeichen fuer gueltige Dateisystem-Pfade.

**Verification method:**
Unit Tests mit Dateisystem-Fixtures
