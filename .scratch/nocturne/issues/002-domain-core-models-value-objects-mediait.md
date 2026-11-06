# 002: Domain Core Models & Value Objects (MediaItem, Chapter, Queue)

**What to build:**
Plattformunabhaengige Dart-Domainmodelle fuer MediaItem, MediaType, Chapter, Bookmark, MediaSource und PlaybackPosition ohne Flutter-Abhaengigkeiten.

**Blocked by:**
TICK-001

**Phase:** Phase 1: Setup & Core Domain
**Type:** Tracer Bullet | **Layer:** Domain Core | **Points:** 3 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] MediaItem unterstuetzt Typen: Audiobook, PodcastEpisode, YouTubeAudio, YouTubeVideo.
- [ ] Chapter-Modell erlaubt hierarchische und lineare Kapitel mit Start- und Endzeitstempeln.
- [ ] Bookmark speichert Millisekunden-Position, Zeitstempel und optionale Notiz.
- [ ] Value Objects sind unveraenderlich (immutable) und implementieren Gleichheitstests.
- [ ] 100% Testabdeckung fuer Serialisierung und Validierungslogik in Domain-Tests.

**Verification method:**
Unit Tests (dart test)
