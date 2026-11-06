# 025: RSS Podcast Feed Parser & Episode Downloader

**What to build:**
RSS 2.0 / iTunes XML Podcast Feed Parser mit Episodenverwaltung, automatischem Download und Kapitelmarken.

**Blocked by:**
TICK-003, TICK-024

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Feature | **Layer:** Domain & Data | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Parst beliebige RSS-Podcast-URLs gemaess RSS 2.0 und Apple Podcasts DTD.
- [ ] Extrahiert Episodenliste, Shownotes, Veroeffentlichungsdatum und Audio-Enclosures.
- [ ] Unterstuetzt Streaming und wahlweisen Offline-Download von Episoden.
- [ ] Speichert Abonnements und gehoerte Episoden in der lokalen Drift-Datenbank.

**Verification method:**
RSS Parser Unit Tests mit Standard-Feeds
