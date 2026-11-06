# 036: End-to-End Schlafsimulations- & Schuetteltest (Mock Audio & Sensor)

**What to build:**
Automatisierter Integrationstest: Simuliert kompletten 30-Minuten-Einschlafzyklus, Fade-Out, Schuetteln auf Matratze und finalen AudioFocus-Verlust.

**Blocked by:**
TICK-016, TICK-017, TICK-018, TICK-029, TICK-035

**Phase:** Phase 6: CI/CD & Testing
**Type:** Testing | **Layer:** Testing & QA | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Testdurchlauf simuliert Zeitraffung (Fast-Forward) eines kompletten Nachtzyklus.
- [ ] Mock-Sensor speist Schuettelbewegungen fuer Profil A und Profil B ein.
- [ ] Bestaetigung des Bluetooth-Auto-Disconnects (abandonAudioFocus) nach Grace-Period.
- [ ] Keine Speicherlecks (Memory Leaks) oder offenen WakeLocks nach Testende.

**Verification method:**
Flutter Integration Test Suite
