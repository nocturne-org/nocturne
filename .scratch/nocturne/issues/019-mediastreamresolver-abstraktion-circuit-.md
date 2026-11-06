# 019: MediaStreamResolver Abstraktion & Circuit-Breaker Router

**What to build:**
Generische Resolver-Schnittstelle MediaStreamResolver und Router mit Circuit-Breaker-Pattern fuer automatischen Tier-Failover.

**Blocked by:**
TICK-002, TICK-006

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Foundation | **Layer:** Domain & Data | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Interface MediaStreamResolver definiert resolveStream, getMetadata, healthCheck.
- [ ] Circuit-Breaker schaltet nach 2 Fehlversuchen oder HTTP 403 auf Tier 2 um.
- [ ] Fallback-Kaskade Tier 1 (Lokal) -> Tier 2 (Invidious) -> Tier 3 (Remote Config).
- [ ] Statistische Erfolgs- und Latenzmetriken je Resolver-Endpunkt.

**Verification method:**
Circuit-Breaker Unit Tests mit Mock-Fehlern
