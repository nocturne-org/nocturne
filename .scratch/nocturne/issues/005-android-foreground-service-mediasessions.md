# 005: Android Foreground Service & MediaSessionService Binding

**What to build:**
Android MediaSessionService mit FOREGROUND_SERVICE_MEDIA_PLAYBACK, PARTIAL_WAKE_LOCK und Media-Notification fuer unterbrechungsfreie Hintergrundwiedergabe.

**Blocked by:**
TICK-001

**Phase:** Phase 1: Setup & Core Domain
**Type:** Tracer Bullet | **Layer:** Platform / Audio | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Foreground Service startet zuverlaessig bei Wiedergabebeginn.
- [ ] Wiedergabe laeuft im Hintergrund bei gesperrtem Bildschirm ohne Doze-Unterbrechung weiter.
- [ ] System-Benachrichtigung zeigt Titel, Cover, Play/Pause und 15s Spul-Aktionen.
- [ ] Media3 / MediaSession-Events reagieren auf Headset-Tasten und Bluetooth-Geraete.

**Verification method:**
Android Integration Test & Device Run
