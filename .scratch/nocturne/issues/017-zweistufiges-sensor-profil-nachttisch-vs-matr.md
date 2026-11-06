# 017: Zweistufiges Sensor-Profil (Nachttisch- vs. Matratzen-Modus)

**What to build:**
Umschaltbare Empfindlichkeitsprofile: Profil A (Nachttisch/Hand, 12 m/s²) und Profil B (Matratze/Kissen, 7.5 m/s²).

**Blocked by:**
TICK-016

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** Feature | **Layer:** Platform & Domain | **Points:** 3 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Profil A loest bei Schwellenwert > 12.0 m/s² aus (Schutz vor Erschuetterungen).
- [ ] Profil B loest sensitiv bei > 7.5 m/s² aus (Kompensation von Schaumstoffdaempfung).
- [ ] Profil ist in App-Einstellungen und Schnellzugriff im Bedtime-Player umschaltbar.
- [ ] Status wird persistent in den Nutzereinstellungen gespeichert.

**Verification method:**
Unit Tests mit kalibrierten Beschleunigungsdaten
