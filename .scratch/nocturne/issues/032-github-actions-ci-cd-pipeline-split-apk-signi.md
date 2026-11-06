# 032: GitHub Actions CI/CD Pipeline & Split APK Signing

**What to build:**
Automatisierte CI/CD-Pipeline in GitHub Actions zum Erstellen, Signieren und Veroeffentlichen schlanker Release-APKs.

**Blocked by:**
Keine (Start sofort)

**Phase:** Phase 6: CI/CD & Testing
**Type:** DevOps | **Layer:** CI/CD & DevOps | **Points:** 3 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Automatischer Build von arm64-v8a Split-APK und universal-APK bei Tag-Push.
- [ ] Signierung mit sicher in GitHub Secrets hinterlegtem Production-Keystore.
- [ ] Automatische Erstellung von SHA-256 Pruefsummen fuer jedes Artefakt.
- [ ] Release-Erstellung auf GitHub mit generierten Release-Notes.

**Verification method:**
GitHub Actions Workflow Dry-Run
