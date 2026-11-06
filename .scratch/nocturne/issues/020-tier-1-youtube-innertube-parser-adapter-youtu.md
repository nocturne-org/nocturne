# 020: Tier 1: YouTube InnerTube Parser Adapter (youtube_explode_dart)

**What to build:**
In-App Streaming-Adapter fuer YouTube-Inhalte basierend auf InnerTube-Client mit Entschluesselung von Signatur-Chiffren.

**Blocked by:**
TICK-019

**Phase:** Phase 4: Streaming & Resolvers
**Type:** Adapter | **Layer:** Data / Resolver | **Points:** 5 | **Priority:** P0
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Extrahiert Audio-Streams und Video-Streams aus regulaeren und Kurz-URLs.
- [ ] Entschluesselt n-sig Parameter zur Vermeidung von Bandbreitendrosselung.
- [ ] Liest Metadaten (Titel, Kanal, Dauer, Thumbnail-URL) aus.
- [ ] Liefert standardisierte Stream-Manifeste an den MediaStreamResolver Router.

**Verification method:**
Integration Tests gegen Referenz-Streams
