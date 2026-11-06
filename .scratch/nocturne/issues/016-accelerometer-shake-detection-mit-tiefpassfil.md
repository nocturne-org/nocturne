# 016: Accelerometer Shake Detection mit Tiefpassfilter & Haptik

**What to build:**
Signalverarbeitung des Beschleunigungssensors via sensors_plus mit Software-Tiefpassfilter und dezentem Haptik-Feedback.

**Blocked by:**
TICK-005, TICK-013

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** Feature | **Layer:** Platform / Sensors | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Filtert kontinuierliche Gravitation und Atembewegungen durch Tiefpassfilter heraus.
- [ ] Erkennt Vorzeichenwechsel und Beschleunigungsspitzen innerhalb eines 600 ms Fensters.
- [ ] Dezente Haptik-Bestaetigung (15 ms Vibration), kein Wecken des Bettpartners.
- [ ] Funktioniert zuverlaessig bei ausgeschaltetem Bildschirm im Hintergrund.

**Verification method:**
Sensor Driver Tests mit synthetischen Vektordaten
