# 004: Riverpod State-Management & Dependency-Injection Graph

**What to build:**
Strukturierter Riverpod Provider-Baum zur Entkopplung von UI, Repositories und Platform-Services mit Unterstuetzung fuer Test-Overrides.

**Blocked by:**
TICK-003

**Phase:** Phase 1: Setup & Core Domain
**Type:** Foundation | **Layer:** Presentation / State | **Points:** 3 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Provider fuer Database, MediaRepository, AudioService und TimerController angelegt.
- [ ] AsyncNotifier-Muster fuer asynchrone Datenzustaende (Laden, Fehler, Daten).
- [ ] Ueberschreibbarkeit (Overrides) in Widget-Tests ohne echte Audio-Treiber.
- [ ] Keine Service-Locator Singletons; vollstaendiges Dependency Injection Schema.

**Verification method:**
Riverpod Provider Tests
