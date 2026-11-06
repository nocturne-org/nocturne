# 034: Obtainium Kompatibilitaet & Metadaten-Standardisierung

**What to build:**
Optimierung der Release-Struktur fuer automatische Updates ueber den Open-Source App-Manager Obtainium.

**Blocked by:**
TICK-032

**Phase:** Phase 6: CI/CD & Testing
**Type:** DevOps | **Layer:** Distribution | **Points:** 2 | **Priority:** P2
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Release-Tag-Schema folgt streng vX.Y.Z SemVer-Standard.
- [ ] APK-Dateinamen sind eindeutig nach Schema Nocturne-vX.Y.Z-arm64-v8a.apk benannt.
- [ ] Obtainium erkennt neue Versionen, filtert passende APK und installiert fehlerfrei.
- [ ] Dokumentierte Ein-Klick-Anleitung fuer Endanwender im README.

**Verification method:**
Obtainium Import & Tracking Test
