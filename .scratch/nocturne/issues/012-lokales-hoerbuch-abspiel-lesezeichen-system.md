# 012: Lokales Hoerbuch-Abspiel- & Lesezeichen-System

**What to build:**
End-to-End Wiedergabe lokaler Hoerbuecher mit Track-Uebergaengen, Kapitelsprung und millisekundengenauem Auto-Resume.

**Blocked by:**
TICK-003, TICK-006, TICK-010

**Phase:** Phase 2: Local Storage & Library
**Type:** Tracer Bullet | **Layer:** Domain & Presentation | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Nahtlose Wiedergabe von Multi-Track Hoerbuechern und Single-File M4B.
- [ ] Automatisches Setzen des Fortschrittslesezeichens alle 5 Sekunden und beim Pausieren.
- [ ] Wiederaufnahme an exakt der gespeicherten Position nach App-Neustart.
- [ ] Kapitelliste ermoeglicht direktes Anspringen einzelner Abschnitte.

**Verification method:**
End-to-End Playback Test
