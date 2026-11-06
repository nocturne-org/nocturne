# 001: Flutter & Android Projekt-Setup mit Clean Architecture Grundgeruest

**What to build:**
Initialisiertes Flutter 3.x Projekt mit Clean Architecture Ordnerstruktur (domain, data, presentation, platform), Flavor-Konfiguration, pubspec.yaml und CI-Build-Faehigkeit.

**Blocked by:**
Keine (Start sofort)

**Phase:** Phase 1: Setup & Core Domain
**Type:** Foundation | **Layer:** Platform / Infra | **Points:** 3 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Flutter Projekt kompiliert fehlerfrei fuer Android (arm64-v8a und universal).
- [ ] Ordnerhierarchie lib/domain, lib/data, lib/presentation, lib/platform ist etabliert.
- [ ] pubspec.yaml enthaelt Core-Dependencies (riverpod, just_audio, drift, sensors_plus).
- [ ] Linting-Regeln mit flutter_lints und strikten Analyse-Optionen konfiguriert.
- [ ] Basis-App startet in Emulator oder Testgeraet mit leerem AMOLED-Container.

**Verification method:**
CI Build & flutter analyze
