# 029: Unified Playback Queue (Audiobuch, Podcast & YouTube)

**What to build:**
Einheitliche Abspiel-Warteschlange fuer nahtlose Mischung von lokalen Dateien, Podcast-Folgen und YouTube-Audiotracks.

**Blocked by:**
TICK-004, TICK-012, TICK-023, TICK-025

**Phase:** Phase 5: UI & Bedtime Player
**Type:** Tracer Bullet | **Layer:** Domain & Presentation | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Warteschlange akzeptiert beliebige Kombinationen der unterstuetzten Medientypen.
- [ ] Automatischer, unterbrechungsfreier Uebergang zum naechsten Track in der Queue.
- [ ] Reordering (Drag & Drop) und Entfernen von Eintraegen per Wischgeste.
- [ ] Queue-Zustand wird persistent in Drift-Datenbank gesichert.

**Verification method:**
Queue Management & State Tests
