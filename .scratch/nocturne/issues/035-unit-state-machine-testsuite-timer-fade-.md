# 035: Unit- & State-Machine-Testsuite (Timer, Fade & Auto-Rewind)

**What to build:**
Vollstaendige Testabdeckung der mathematischen Fade-Funktion, der Timer-Zustaende, des Auto-Rewinds und der Grace-Period.

**Blocked by:**
TICK-013, TICK-014, TICK-015, TICK-018

**Phase:** Phase 6: CI/CD & Testing
**Type:** Testing | **Layer:** Testing & QA | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Unit-Tests fuer die mathematische Korrektheit der quadratischen Drosselungskurve.
- [ ] Simulation aller Timer-Uebergaenge (Start, Pause, Reset, Timeout, Grace).
- [ ] Verifikation des -45s Auto-Rewind Offsets bei Ablauf des Timers.
- [ ] Mindestens 90% Code-Coverage im Domain- und Timer-Paket.

**Verification method:**
dart test --coverage
