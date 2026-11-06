# 001: Flutter & Android Projekt-Setup mit Clean Architecture Grundgeruest

**What to build:**
Initialisiertes Flutter 3.x Projekt mit Clean Architecture Ordnerstruktur (domain, data, presentation, platform), Flavor-Konfiguration, pubspec.yaml und CI-Build-Faehigkeit.

**Blocked by:**
Keine (Start sofort)

**Phase:** Phase 1: Setup & Core Domain
**Type:** Foundation | **Layer:** Platform / Infra | **Points:** 3 | **Priority:** P0
**Status:** completed

**Acceptance criteria:**
- [x] Flutter Projekt kompiliert fehlerfrei fuer Android (arm64-v8a und universal).
- [x] Ordnerhierarchie lib/domain, lib/data, lib/presentation, lib/platform ist etabliert.
- [x] pubspec.yaml enthaelt Core-Dependencies (riverpod, just_audio, drift, sensors_plus).
- [x] Linting-Regeln mit flutter_lints und strikten Analyse-Optionen konfiguriert.
- [x] Basis-App startet in Emulator oder Testgeraet mit leerem AMOLED-Container.

**Verification method:**
CI Build & flutter analyze
