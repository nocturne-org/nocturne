# 008: Interne App-Sandbox Storage Provider & Dateimanager

**What to build:**
Sicherer interner Sandbox-Speicheranbieter (/data/user/0/com.nocturne.audio/files/) fuer Downloads, Cache und Cover-Art.

**Blocked by:**
Keine (Start sofort)

**Phase:** Phase 2: Local Storage & Library
**Type:** Foundation | **Layer:** Data / Storage | **Points:** 3 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Eindeutige Verzeichnis-Pfade fuer audio_downloads, podcast_cache und cover_cache.
- [ ] Schutz vor Bereinigungs-Apps von Drittanbietern und Android-Systembereinigung.
- [ ] Automatisches Aufraeumen verwaister Download-Fragmente (.part-Dateien).
- [ ] Speicherplatz-Pruefung vor grossen Downloads mit Warnung bei Restkapazitaet < 500 MB.

**Verification method:**
Unit Tests mit Temp-Verzeichnis
