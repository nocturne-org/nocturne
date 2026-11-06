# 003: Drift SQLite Datenbankschema & Persistenz-Layer

**What to build:**
Lokale SQLite-Datenbank via Drift mit Tabellen fuer media_items, bookmarks, playback_history und sleep_presets sowie typensicheren DAOs.

**Blocked by:**
TICK-002

**Phase:** Phase 1: Setup & Core Domain
**Type:** Foundation | **Layer:** Data / SQLite | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Tabellen media_items, bookmarks, playback_history, sleep_presets sind definiert.
- [ ] Drift DAOs bieten reaktive Streams (watch) und asynchrone CRUD-Methoden.
- [ ] Millisekunden-genaue Speicherung und Abruf der letzten Abspielposition.
- [ ] Transaktionale Integritaet bei Batch-Updates (z. B. Ordner-Scan Import).
- [ ] In-Memory SQLite Unit-Tests verifizieren saemtliche Abfragen und Kaskadierungen.

**Verification method:**
Unit Tests mit in-memory SQLite
