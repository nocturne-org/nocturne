# 009: Rekursiver Library-Scanner & Format-Detektor

**What to build:**
Hintergrund-Scanner fuer Audioformate (.mp3, .m4b, .m4a, .flac, .opus) mit Isolate-Traversierung ohne Belastung des UI-Threads.

**Blocked by:**
TICK-003, TICK-007

**Phase:** Phase 2: Local Storage & Library
**Type:** Tracer Bullet | **Layer:** Data & Domain | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Findet alle unterstuetzten Audioformate rekursiv in eingebundenen Pfaden.
- [ ] Traversierung laeuft in separatem Dart Isolate; UI bleibt konstant bei 60 fps.
- [ ] Fortschritts-Events (Gescannte Dateien / Gesamtanzahl) an UI uebertragen.
- [ ] Erkennt Aenderungen, Neuzugaenge und geloeschte Dateien inkrementell.

**Verification method:**
Integration Test mit Mock-Verzeichnisbaum
