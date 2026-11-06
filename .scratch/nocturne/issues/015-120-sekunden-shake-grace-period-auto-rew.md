# 015: 120-Sekunden Shake-Grace-Period & Auto-Rewind-Bookmarking

**What to build:**
120-Sekunden Grace-Period bei Stille mit Auto-Rewind-Lesezeichen 45 Sekunden vor Beginn des Fade-Outs.

**Blocked by:**
TICK-012, TICK-014

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** Feature | **Layer:** Domain & Audio | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Beim Uebergang zu GracePeriod wird ein Lesezeichen bei Position = Position_fade - 45s gesetzt.
- [ ] Sensor und WakeLock bleiben fuer genau 120 Sekunden aktiv.
- [ ] Schuetteln waehrend Grace-Period reaktiviert Wiedergabe mit sanftem Fade-In.
- [ ] Ohne Schuetteln innerhalb 120s: Uebergang zu Gestoppt, Freigabe aller Ressourcen.

**Verification method:**
Timing & State-Machine Unit Tests
