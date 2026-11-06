# 006: JustAudio Engine Adapter & AudioFocus Manager

**What to build:**
Adapter-Schicht um just_audio und audio_session mit Fokus-Handling (Ducking, Pause bei Anruf) und unterbrechungsfreiem Stream-Switching.

**Blocked by:**
TICK-005

**Phase:** Phase 1: Setup & Core Domain
**Type:** Adapter | **Layer:** Platform / Audio | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] AudioSession ist fuer Media/Speech konfiguriert (AUDIOFOCUS_GAIN).
- [ ] Automatisches Pausieren bei eingehenden Telefonaten oder transientem Fokusverlust.
- [ ] Ducking bei Navigations- oder kurzen Hinweistoenen.
- [ ] Buffer-Management fuer fluessiges Pre-Buffering des naechsten Tracks.

**Verification method:**
Audio Focus Unit & Mock Tests
