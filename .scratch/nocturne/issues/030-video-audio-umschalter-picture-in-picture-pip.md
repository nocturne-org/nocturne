# 030: Video/Audio Umschalter & Picture-in-Picture (PiP) Modus

**What to build:**
Nahtloser Umschalter zwischen reinem Audio- und Videoplayer fuer YouTube-Inhalte inklusive Android Picture-in-Picture Support.

**Blocked by:**
TICK-020, TICK-027

**Phase:** Phase 5: UI & Bedtime Player
**Type:** Feature | **Layer:** Presentation / Video | **Points:** 5 | **Priority:** P2
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Umschalt-Taste wechselt ohne Abspielunterbrechung zwischen Video und Reinaudio.
- [ ] Video wird bei Verlassen der App oder Home-Geste automatisch im PiP-Fenster gezeigt.
- [ ] Beim Ausschalten des Bildschirms wird sofort in den akkuschonenden Audio-Modus gewechselt.
- [ ] Kein Videodecoder-Ressourcenverbrauch im reinen Audio-Modus.

**Verification method:**
Android PiP Lifecycle Tests
