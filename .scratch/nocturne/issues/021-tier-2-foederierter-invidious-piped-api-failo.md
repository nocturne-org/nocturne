# 021: Tier 2: Foederierter Invidious & Piped API Failover-Adapter

**What to build:**
REST-Client fuer dezentrale Invidious- und Piped-Instanzen als Stufe-2-Fallback bei Bot-Blockaden von Stufe 1.

**Blocked by:**
TICK-019

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Adapter | **Layer:** Data / Resolver | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Kuratierte Liste oeffentlicher, gesunder Invidious/Piped Instanzen integriert.
- [ ] Automatischer Health-Check (Ping / Latenz) vor Stream-Abruf.
- [ ] Nahtlose Bereitstellung des Audiostreams ohne Nutzerinteraktion bei Tier-1-Ausfall.
- [ ] Timeout-Absicherung (maximal 3,5s pro Instanz) vor Weiterschaltung.

**Verification method:**
Mock HTTP Client Tests
