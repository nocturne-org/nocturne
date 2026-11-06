# 033: In-App Self-Updater via GitHub Releases API

**What to build:**
Integrierter Updater, der GitHub Releases prueft, die passende arm64-v8a APK laedt, Pruefsummen verifiziert und die Installation startet.

**Blocked by:**
TICK-032

**Phase:** Phase 6: CI/CD & Testing
**Type:** Feature | **Layer:** Platform / Update | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Prueft im Hintergrund auf neuere Versionen ueber die GitHub Releases API.
- [ ] Erkennt CPU-Architektur des Endgeraets (bevorzugt 18 MB arm64-v8a Split-APK).
- [ ] Verifiziert SHA-256 Hash der heruntergeladenen Datei vor der Installation.
- [ ] Startet Android Package-Installer Intent fuer nahtloses Update.

**Verification method:**
Updater Logic & Hash Verification Tests
