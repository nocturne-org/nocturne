# 024: Background Offline Download Manager mit Tag-Injektion

**What to build:**
Download-Manager fuer Offline-Audio/Video in die interne Sandbox mit automatischer Metadaten- und Cover-Injektion.

**Blocked by:**
TICK-008, TICK-020

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Tracer Bullet | **Layer:** Data & Platform | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Download-Warteschlange mit Pausieren, Fortsetzen und Abbruch.
- [ ] Downloads laufen im Android Foreground Service zuverlaessig im Hintergrund.
- [ ] Injektion gueltiger ID3v2-Tags (Titel, Uploader als Kuenstler, Cover) in MP3/M4A.
- [ ] Heruntergeladene Dateien erscheinen sofort in der lokalen Bibliothek.

**Verification method:**
Download Manager Integration Tests
