# 023: Audio-Only Stream Optimierung (M4A/Opus 128-160 kbps)

**What to build:**
Selektion reiner Audio-Bitstreams (M4A / Opus mit 128-160 kbps) mit 85-90% Bandbreiten- und Akku-Einsparung bei YouTube-Inhalten.

**Blocked by:**
TICK-020

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Feature | **Layer:** Domain & Audio | **Points:** 3 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Filtert Video-Streams vollstaendig heraus, wenn Audio-Modus aktiv ist.
- [ ] Waehlt den qualitativ besten Audio-Container (Opus 160k oder M4A 128k).
- [ ] Reduziert Netzwerkdatenverbrauch um mindestens 85% gegenueber 1080p Video.
- [ ] Buffer-Optimierung fuer schnellen Start innerhalb von 800 ms.

**Verification method:**
Network Consumption & Bandwidth Tests
