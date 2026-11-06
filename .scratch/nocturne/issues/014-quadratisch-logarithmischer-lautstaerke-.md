# 014: Quadratisch-Logarithmischer Lautstaerke-Fade-Out (60s Blende)

**What to build:**
Implementierung der Fade-Out Funktion Volume(t) = Volume_start * (t_rest / 60)^2 fuer die letzten 60 Sekunden der Wiedergabe.

**Blocked by:**
TICK-006, TICK-013

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** DSP & Audio | **Layer:** Domain & Audio | **Points:** 3 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Fade-Out startet exakt bei Restzeit = 60 Sekunden.
- [ ] Lautstaerke folgt der quadratischen Kurve ohne akustische Spruenge oder Klicklaute.
- [ ] Schuetteln waehrend Ausblendend setzt Lautstaerke sofort auf 100% und verlaengert um 15 Min.
- [ ] Bei Restzeit = 0 wird Lautstaerke auf 0 gesetzt und Zustand GracePeriod betreten.

**Verification method:**
Unit & Audio-Ramp Tests
