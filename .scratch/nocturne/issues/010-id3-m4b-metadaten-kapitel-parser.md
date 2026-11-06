# 010: ID3 & M4B Metadaten- & Kapitel-Parser

**What to build:**
Extraktion von ID3v1/ID3v2-Tags und M4B/QuickTime-Atomen (Titel, Autor, Album, Track, Cover, eingebettete Kapitelmarken).

**Blocked by:**
TICK-002, TICK-009

**Phase:** Phase 2: Local Storage & Library
**Type:** Feature | **Layer:** Data / MediaParser | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Extrahiert Titel, Kuenstler/Autor, Album/Buchname, Tracknummer und Jahr.
- [ ] Liest M4B QuickTime Kapitel-Atome mit sekundengenauen Markierungen aus.
- [ ] Extrahiert eingebettete Coverbilder und legt sie im Cache-Speicher ab.
- [ ] Robuster Fallback auf Dateinamen, falls Metadaten beschaedigt oder leer sind.

**Verification method:**
Unit Tests mit Test-MP3 und Test-M4B Fixtures
