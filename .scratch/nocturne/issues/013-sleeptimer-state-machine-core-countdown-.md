# 013: SleepTimer State-Machine & Core Countdown Engine

**What to build:**
Reaktive Zustandsmaschine fuer den Schlaftimer mit Zustaenden Inaktiv, Zaehlend, Ausblendend, GracePeriod und Gestoppt.

**Blocked by:**
TICK-002, TICK-004

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** Tracer Bullet | **Layer:** Domain Core | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Zustandsuebergaenge strikt gemaess Spezifikation abgebildet.
- [ ] Presets fuer 15, 30, 45, 60 Minuten und 'Bis Kapitelende'.
- [ ] Sekuendliche Ticks mit Millisekunden-Genauigkeit an Riverpod-State.
- [ ] Schuettel-Event waehrend Zaehlend verlaengert Timer um konfigurierbare Zeit (+15 Min).

**Verification method:**
State-Machine Unit Tests
