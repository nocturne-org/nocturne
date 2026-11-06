# Nocturne - Entwicklungs-Backlog & Ticket-Katalog

Dieses Dokument enthaelt saemtliche 36 Entwicklungs-Tickets fuer Nocturne, aufgeteilt in 6 Phasen.
Die formatierte Excel-Tabelle befindet sich unter `docs/tickets/nocturne_tickets.xlsx`.

---

## Phase 1: Setup & Core Domain

### TICK-001: Flutter & Android Projekt-Setup mit Clean Architecture Grundgeruest

- **Deliverable:** Initialisiertes Flutter 3.x Projekt mit Clean Architecture Ordnerstruktur (domain, data, presentation, platform), Flavor-Konfiguration, pubspec.yaml und CI-Build-Faehigkeit.
- **Blocked by:** Keine (Start sofort)
- **Prio / Points:** P0 | 3 Story Points
- **Typ / Schicht:** Foundation | Platform / Infra
- **Status:** `Ready for Dev`
- **Akzeptanzkriterien:**
  - [ ] Flutter Projekt kompiliert fehlerfrei fuer Android (arm64-v8a und universal).
  - [ ] Ordnerhierarchie lib/domain, lib/data, lib/presentation, lib/platform ist etabliert.
  - [ ] pubspec.yaml enthaelt Core-Dependencies (riverpod, just_audio, drift, sensors_plus).
  - [ ] Linting-Regeln mit flutter_lints und strikten Analyse-Optionen konfiguriert.
  - [ ] Basis-App startet in Emulator oder Testgeraet mit leerem AMOLED-Container.
- **Verifikation:** CI Build & flutter analyze

### TICK-002: Domain Core Models & Value Objects (MediaItem, Chapter, Queue)

- **Deliverable:** Plattformunabhaengige Dart-Domainmodelle fuer MediaItem, MediaType, Chapter, Bookmark, MediaSource und PlaybackPosition ohne Flutter-Abhaengigkeiten.
- **Blocked by:** TICK-001
- **Prio / Points:** P0 | 3 Story Points
- **Typ / Schicht:** Tracer Bullet | Domain Core
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] MediaItem unterstuetzt Typen: Audiobook, PodcastEpisode, YouTubeAudio, YouTubeVideo.
  - [ ] Chapter-Modell erlaubt hierarchische und lineare Kapitel mit Start- und Endzeitstempeln.
  - [ ] Bookmark speichert Millisekunden-Position, Zeitstempel und optionale Notiz.
  - [ ] Value Objects sind unveraenderlich (immutable) und implementieren Gleichheitstests.
  - [ ] 100% Testabdeckung fuer Serialisierung und Validierungslogik in Domain-Tests.
- **Verifikation:** Unit Tests (dart test)

### TICK-003: Drift SQLite Datenbankschema & Persistenz-Layer

- **Deliverable:** Lokale SQLite-Datenbank via Drift mit Tabellen fuer media_items, bookmarks, playback_history und sleep_presets sowie typensicheren DAOs.
- **Blocked by:** TICK-002
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Foundation | Data / SQLite
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Tabellen media_items, bookmarks, playback_history, sleep_presets sind definiert.
  - [ ] Drift DAOs bieten reaktive Streams (watch) und asynchrone CRUD-Methoden.
  - [ ] Millisekunden-genaue Speicherung und Abruf der letzten Abspielposition.
  - [ ] Transaktionale Integritaet bei Batch-Updates (z. B. Ordner-Scan Import).
  - [ ] In-Memory SQLite Unit-Tests verifizieren saemtliche Abfragen und Kaskadierungen.
- **Verifikation:** Unit Tests mit in-memory SQLite

### TICK-004: Riverpod State-Management & Dependency-Injection Graph

- **Deliverable:** Strukturierter Riverpod Provider-Baum zur Entkopplung von UI, Repositories und Platform-Services mit Unterstuetzung fuer Test-Overrides.
- **Blocked by:** TICK-003
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Foundation | Presentation / State
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Provider fuer Database, MediaRepository, AudioService und TimerController angelegt.
  - [ ] AsyncNotifier-Muster fuer asynchrone Datenzustaende (Laden, Fehler, Daten).
  - [ ] Ueberschreibbarkeit (Overrides) in Widget-Tests ohne echte Audio-Treiber.
  - [ ] Keine Service-Locator Singletons; vollstaendiges Dependency Injection Schema.
- **Verifikation:** Riverpod Provider Tests

### TICK-005: Android Foreground Service & MediaSessionService Binding

- **Deliverable:** Android MediaSessionService mit FOREGROUND_SERVICE_MEDIA_PLAYBACK, PARTIAL_WAKE_LOCK und Media-Notification fuer unterbrechungsfreie Hintergrundwiedergabe.
- **Blocked by:** TICK-001
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Platform / Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Foreground Service startet zuverlaessig bei Wiedergabebeginn.
  - [ ] Wiedergabe laeuft im Hintergrund bei gesperrtem Bildschirm ohne Doze-Unterbrechung weiter.
  - [ ] System-Benachrichtigung zeigt Titel, Cover, Play/Pause und 15s Spul-Aktionen.
  - [ ] Media3 / MediaSession-Events reagieren auf Headset-Tasten und Bluetooth-Geraete.
- **Verifikation:** Android Integration Test & Device Run

### TICK-006: JustAudio Engine Adapter & AudioFocus Manager

- **Deliverable:** Adapter-Schicht um just_audio und audio_session mit Fokus-Handling (Ducking, Pause bei Anruf) und unterbrechungsfreiem Stream-Switching.
- **Blocked by:** TICK-005
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Adapter | Platform / Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] AudioSession ist fuer Media/Speech konfiguriert (AUDIOFOCUS_GAIN).
  - [ ] Automatisches Pausieren bei eingehenden Telefonaten oder transientem Fokusverlust.
  - [ ] Ducking bei Navigations- oder kurzen Hinweistoenen.
  - [ ] Buffer-Management fuer fluessiges Pre-Buffering des naechsten Tracks.
- **Verifikation:** Audio Focus Unit & Mock Tests

## Phase 2: Local Storage & Library

### TICK-007: Android Storage Access Framework (SAF) Ordner-Picker & Permissions

- **Deliverable:** Integration des Android Storage Access Frameworks (SAF) zur Auswahl externer Hoerbuch-Verzeichnisse mit persistierten Rechten ueber Neustarts.
- **Blocked by:** Keine (Start sofort)
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Feature | Platform / Storage
- **Status:** `Ready for Dev`
- **Akzeptanzkriterien:**
  - [ ] Nutzer kann beliebige Ordner auf internem Speicher oder SD-Karte auswaehlen.
  - [ ] App fordert und speichert takePersistableUriPermission dauerhaft.
  - [ ] Verzeichnis-Berechtigungen bleiben nach Geraeteneustart vollstaendig erhalten.
  - [ ] Fehlertolerante Rueckmeldung, wenn SD-Karte entfernt oder Pfad geloescht wurde.
- **Verifikation:** Manual Verification & SAF Integration

### TICK-008: Interne App-Sandbox Storage Provider & Dateimanager

- **Deliverable:** Sicherer interner Sandbox-Speicheranbieter (/data/user/0/com.nocturne.audio/files/) fuer Downloads, Cache und Cover-Art.
- **Blocked by:** Keine (Start sofort)
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Foundation | Data / Storage
- **Status:** `Ready for Dev`
- **Akzeptanzkriterien:**
  - [ ] Eindeutige Verzeichnis-Pfade fuer audio_downloads, podcast_cache und cover_cache.
  - [ ] Schutz vor Bereinigungs-Apps von Drittanbietern und Android-Systembereinigung.
  - [ ] Automatisches Aufraeumen verwaister Download-Fragmente (.part-Dateien).
  - [ ] Speicherplatz-Pruefung vor grossen Downloads mit Warnung bei Restkapazitaet < 500 MB.
- **Verifikation:** Unit Tests mit Temp-Verzeichnis

### TICK-009: Rekursiver Library-Scanner & Format-Detektor

- **Deliverable:** Hintergrund-Scanner fuer Audioformate (.mp3, .m4b, .m4a, .flac, .opus) mit Isolate-Traversierung ohne Belastung des UI-Threads.
- **Blocked by:** TICK-003, TICK-007
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Data & Domain
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Findet alle unterstuetzten Audioformate rekursiv in eingebundenen Pfaden.
  - [ ] Traversierung laeuft in separatem Dart Isolate; UI bleibt konstant bei 60 fps.
  - [ ] Fortschritts-Events (Gescannte Dateien / Gesamtanzahl) an UI uebertragen.
  - [ ] Erkennt Aenderungen, Neuzugaenge und geloeschte Dateien inkrementell.
- **Verifikation:** Integration Test mit Mock-Verzeichnisbaum

### TICK-010: ID3 & M4B Metadaten- & Kapitel-Parser

- **Deliverable:** Extraktion von ID3v1/ID3v2-Tags und M4B/QuickTime-Atomen (Titel, Autor, Album, Track, Cover, eingebettete Kapitelmarken).
- **Blocked by:** TICK-002, TICK-009
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Feature | Data / MediaParser
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Extrahiert Titel, Kuenstler/Autor, Album/Buchname, Tracknummer und Jahr.
  - [ ] Liest M4B QuickTime Kapitel-Atome mit sekundengenauen Markierungen aus.
  - [ ] Extrahiert eingebettete Coverbilder und legt sie im Cache-Speicher ab.
  - [ ] Robuster Fallback auf Dateinamen, falls Metadaten beschaedigt oder leer sind.
- **Verifikation:** Unit Tests mit Test-MP3 und Test-M4B Fixtures

### TICK-011: Smart Library Auto-Organizer (ID3 zu Ordner-Hierarchie)

- **Deliverable:** Automatisches Sortier- und Verschiebe-Werkzeug nach dem Schema: Autor / Buchname / Track - Titel.ext inklusive Duplikaterkennung.
- **Blocked by:** TICK-010
- **Prio / Points:** P2 | 5 Story Points
- **Typ / Schicht:** Feature | Domain & Storage
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Erkennt unstrukturierte oder falsch abgelegte Audiodateien in Zielordnern.
  - [ ] Vorschau-Modus (Dry-Run): Zeigt geplante Aenderungen vor Ausfuehrung.
  - [ ] Atomare Verschiebung mit Rollback-Sicherheit bei Dateisystem-Fehlern.
  - [ ] Sanitisierung von Sonderzeichen fuer gueltige Dateisystem-Pfade.
- **Verifikation:** Unit Tests mit Dateisystem-Fixtures

### TICK-012: Lokales Hoerbuch-Abspiel- & Lesezeichen-System

- **Deliverable:** End-to-End Wiedergabe lokaler Hoerbuecher mit Track-Uebergaengen, Kapitelsprung und millisekundengenauem Auto-Resume.
- **Blocked by:** TICK-003, TICK-006, TICK-010
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Domain & Presentation
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Nahtlose Wiedergabe von Multi-Track Hoerbuechern und Single-File M4B.
  - [ ] Automatisches Setzen des Fortschrittslesezeichens alle 5 Sekunden und beim Pausieren.
  - [ ] Wiederaufnahme an exakt der gespeicherten Position nach App-Neustart.
  - [ ] Kapitelliste ermoeglicht direktes Anspringen einzelner Abschnitte.
- **Verifikation:** End-to-End Playback Test

## Phase 3: Bedtime Engine & Sensorik

### TICK-013: SleepTimer State-Machine & Core Countdown Engine

- **Deliverable:** Reaktive Zustandsmaschine fuer den Schlaftimer mit Zustaenden Inaktiv, Zaehlend, Ausblendend, GracePeriod und Gestoppt.
- **Blocked by:** TICK-002, TICK-004
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Domain Core
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Zustandsuebergaenge strikt gemaess Spezifikation abgebildet.
  - [ ] Presets fuer 15, 30, 45, 60 Minuten und 'Bis Kapitelende'.
  - [ ] Sekuendliche Ticks mit Millisekunden-Genauigkeit an Riverpod-State.
  - [ ] Schuettel-Event waehrend Zaehlend verlaengert Timer um konfigurierbare Zeit (+15 Min).
- **Verifikation:** State-Machine Unit Tests

### TICK-014: Quadratisch-Logarithmischer Lautstaerke-Fade-Out (60s Blende)

- **Deliverable:** Implementierung der Fade-Out Funktion Volume(t) = Volume_start * (t_rest / 60)^2 fuer die letzten 60 Sekunden der Wiedergabe.
- **Blocked by:** TICK-006, TICK-013
- **Prio / Points:** P0 | 3 Story Points
- **Typ / Schicht:** DSP & Audio | Domain & Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Fade-Out startet exakt bei Restzeit = 60 Sekunden.
  - [ ] Lautstaerke folgt der quadratischen Kurve ohne akustische Spruenge oder Klicklaute.
  - [ ] Schuetteln waehrend Ausblendend setzt Lautstaerke sofort auf 100% und verlaengert um 15 Min.
  - [ ] Bei Restzeit = 0 wird Lautstaerke auf 0 gesetzt und Zustand GracePeriod betreten.
- **Verifikation:** Unit & Audio-Ramp Tests

### TICK-015: 120-Sekunden Shake-Grace-Period & Auto-Rewind-Bookmarking

- **Deliverable:** 120-Sekunden Grace-Period bei Stille mit Auto-Rewind-Lesezeichen 45 Sekunden vor Beginn des Fade-Outs.
- **Blocked by:** TICK-012, TICK-014
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Feature | Domain & Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Beim Uebergang zu GracePeriod wird ein Lesezeichen bei Position = Position_fade - 45s gesetzt.
  - [ ] Sensor und WakeLock bleiben fuer genau 120 Sekunden aktiv.
  - [ ] Schuetteln waehrend Grace-Period reaktiviert Wiedergabe mit sanftem Fade-In.
  - [ ] Ohne Schuetteln innerhalb 120s: Uebergang zu Gestoppt, Freigabe aller Ressourcen.
- **Verifikation:** Timing & State-Machine Unit Tests

### TICK-016: Accelerometer Shake Detection mit Tiefpassfilter & Haptik

- **Deliverable:** Signalverarbeitung des Beschleunigungssensors via sensors_plus mit Software-Tiefpassfilter und dezentem Haptik-Feedback.
- **Blocked by:** TICK-005, TICK-013
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Feature | Platform / Sensors
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Filtert kontinuierliche Gravitation und Atembewegungen durch Tiefpassfilter heraus.
  - [ ] Erkennt Vorzeichenwechsel und Beschleunigungsspitzen innerhalb eines 600 ms Fensters.
  - [ ] Dezente Haptik-Bestaetigung (15 ms Vibration), kein Wecken des Bettpartners.
  - [ ] Funktioniert zuverlaessig bei ausgeschaltetem Bildschirm im Hintergrund.
- **Verifikation:** Sensor Driver Tests mit synthetischen Vektordaten

### TICK-017: Zweistufiges Sensor-Profil (Nachttisch- vs. Matratzen-Modus)

- **Deliverable:** Umschaltbare Empfindlichkeitsprofile: Profil A (Nachttisch/Hand, 12 m/s²) und Profil B (Matratze/Kissen, 7.5 m/s²).
- **Blocked by:** TICK-016
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Feature | Platform & Domain
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Profil A loest bei Schwellenwert > 12.0 m/s² aus (Schutz vor Erschuetterungen).
  - [ ] Profil B loest sensitiv bei > 7.5 m/s² aus (Kompensation von Schaumstoffdaempfung).
  - [ ] Profil ist in App-Einstellungen und Schnellzugriff im Bedtime-Player umschaltbar.
  - [ ] Status wird persistent in den Nutzereinstellungen gespeichert.
- **Verifikation:** Unit Tests mit kalibrierten Beschleunigungsdaten

### TICK-018: Whisper Dynamics DSP Audio-Filter & Bluetooth Auto-Disconnect

- **Deliverable:** DSP Dynamik-Kompression (Ratio 4:1, Attack < 10ms, Limiter -3 dBFS), High-Shelf Filter ab 4.5 kHz (-6 dB) und AudioFocus Freigabe.
- **Blocked by:** TICK-006, TICK-015
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** DSP & Audio | Platform / Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Dynamikkompression begrenzt Pegelspitzen von Sprache und Musik auf -3 dBFS.
  - [ ] High-Shelf Cut ab 4.5 kHz daempft Zischlaute bei Nachtlautstaerke (5-10%).
  - [ ] Nach Ablauf der Grace-Period wird abandonAudioFocus() aufgerufen.
  - [ ] Bluetooth-In-Ears wechseln nach Fokusfreigabe selbststaendig in den Standby.
- **Verifikation:** Audio Buffer DSP Analysis & AudioFocus Check

## Phase 4: Streaming & Resolvers

### TICK-019: MediaStreamResolver Abstraktion & Circuit-Breaker Router

- **Deliverable:** Generische Resolver-Schnittstelle MediaStreamResolver und Router mit Circuit-Breaker-Pattern fuer automatischen Tier-Failover.
- **Blocked by:** TICK-002, TICK-006
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Foundation | Domain & Data
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Interface MediaStreamResolver definiert resolveStream, getMetadata, healthCheck.
  - [ ] Circuit-Breaker schaltet nach 2 Fehlversuchen oder HTTP 403 auf Tier 2 um.
  - [ ] Fallback-Kaskade Tier 1 (Lokal) -> Tier 2 (Invidious) -> Tier 3 (Remote Config).
  - [ ] Statistische Erfolgs- und Latenzmetriken je Resolver-Endpunkt.
- **Verifikation:** Circuit-Breaker Unit Tests mit Mock-Fehlern

### TICK-020: Tier 1: YouTube InnerTube Parser Adapter (youtube_explode_dart)

- **Deliverable:** In-App Streaming-Adapter fuer YouTube-Inhalte basierend auf InnerTube-Client mit Entschluesselung von Signatur-Chiffren.
- **Blocked by:** TICK-019
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Adapter | Data / Resolver
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Extrahiert Audio-Streams und Video-Streams aus regulaeren und Kurz-URLs.
  - [ ] Entschluesselt n-sig Parameter zur Vermeidung von Bandbreitendrosselung.
  - [ ] Liest Metadaten (Titel, Kanal, Dauer, Thumbnail-URL) aus.
  - [ ] Liefert standardisierte Stream-Manifeste an den MediaStreamResolver Router.
- **Verifikation:** Integration Tests gegen Referenz-Streams

### TICK-021: Tier 2: Foederierter Invidious & Piped API Failover-Adapter

- **Deliverable:** REST-Client fuer dezentrale Invidious- und Piped-Instanzen als Stufe-2-Fallback bei Bot-Blockaden von Stufe 1.
- **Blocked by:** TICK-019
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Adapter | Data / Resolver
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Kuratierte Liste oeffentlicher, gesunder Invidious/Piped Instanzen integriert.
  - [ ] Automatischer Health-Check (Ping / Latenz) vor Stream-Abruf.
  - [ ] Nahtlose Bereitstellung des Audiostreams ohne Nutzerinteraktion bei Tier-1-Ausfall.
  - [ ] Timeout-Absicherung (maximal 3,5s pro Instanz) vor Weiterschaltung.
- **Verifikation:** Mock HTTP Client Tests

### TICK-022: Tier 3: Dynamic Remote Config Rule Engine (GitHub Raw JSON)

- **Deliverable:** Asynchrone Remote-Konfiguration via GitHub Raw JSON zur dynamischen Aktualisierung von Client-Parametern ohne APK-Update.
- **Blocked by:** TICK-019
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Feature | Data / Config
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Laedt Remote-Config asynchron beim Start der App herunter.
  - [ ] Aktualisiert User-Agents, InnerTube-Client-Versionen und aktive Invidious-Instanzen.
  - [ ] Offline-Cache speichert letzte gueltige Konfiguration persistent.
  - [ ] Kryptografische Signatur- oder Hash-Pruefung gegen Manipulation.
- **Verifikation:** Remote Config Unit Tests & Fixtures

### TICK-023: Audio-Only Stream Optimierung (M4A/Opus 128-160 kbps)

- **Deliverable:** Selektion reiner Audio-Bitstreams (M4A / Opus mit 128-160 kbps) mit 85-90% Bandbreiten- und Akku-Einsparung bei YouTube-Inhalten.
- **Blocked by:** TICK-020
- **Prio / Points:** P0 | 3 Story Points
- **Typ / Schicht:** Feature | Domain & Audio
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Filtert Video-Streams vollstaendig heraus, wenn Audio-Modus aktiv ist.
  - [ ] Waehlt den qualitativ besten Audio-Container (Opus 160k oder M4A 128k).
  - [ ] Reduziert Netzwerkdatenverbrauch um mindestens 85% gegenueber 1080p Video.
  - [ ] Buffer-Optimierung fuer schnellen Start innerhalb von 800 ms.
- **Verifikation:** Network Consumption & Bandwidth Tests

### TICK-024: Background Offline Download Manager mit Tag-Injektion

- **Deliverable:** Download-Manager fuer Offline-Audio/Video in die interne Sandbox mit automatischer Metadaten- und Cover-Injektion.
- **Blocked by:** TICK-008, TICK-020
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Data & Platform
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Download-Warteschlange mit Pausieren, Fortsetzen und Abbruch.
  - [ ] Downloads laufen im Android Foreground Service zuverlaessig im Hintergrund.
  - [ ] Injektion gueltiger ID3v2-Tags (Titel, Uploader als Kuenstler, Cover) in MP3/M4A.
  - [ ] Heruntergeladene Dateien erscheinen sofort in der lokalen Bibliothek.
- **Verifikation:** Download Manager Integration Tests

### TICK-025: RSS Podcast Feed Parser & Episode Downloader

- **Deliverable:** RSS 2.0 / iTunes XML Podcast Feed Parser mit Episodenverwaltung, automatischem Download und Kapitelmarken.
- **Blocked by:** TICK-003, TICK-024
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Feature | Domain & Data
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Parst beliebige RSS-Podcast-URLs gemaess RSS 2.0 und Apple Podcasts DTD.
  - [ ] Extrahiert Episodenliste, Shownotes, Veroeffentlichungsdatum und Audio-Enclosures.
  - [ ] Unterstuetzt Streaming und wahlweisen Offline-Download von Episoden.
  - [ ] Speichert Abonnements und gehoerte Episoden in der lokalen Drift-Datenbank.
- **Verifikation:** RSS Parser Unit Tests mit Standard-Feeds

## Phase 5: UI & Bedtime Player

### TICK-026: AMOLED Pure Black Theme & Bedtime Design System

- **Deliverable:** Design-System mit 100% reinem OLED-Schwarz (#000000), blendfreier Typografie und barrierefreien Touch-Zielen (> 48 dp).
- **Blocked by:** Keine (Start sofort)
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** UI / Design | Presentation / Theme
- **Status:** `Ready for Dev`
- **Akzeptanzkriterien:**
  - [ ] Hintergruende zu 100% #000000 zur Abschaltung von OLED-Pixeln.
  - [ ] Gedaempfte Akzentfarben (Sanftes Bernstein #F59E0B und Nacht-Cyan #06B6D4).
  - [ ] Keine grellen Weiss-Toene (Texte in gedimmtem Off-White #E2E8F0 und #94A3B8).
  - [ ] Alle interaktiven Touch-Flaechen besitzen mindestens 48x48 dp Abmessung.
- **Verifikation:** Flutter Widget & Contrast Tests

### TICK-027: Bedtime Player Screen & Sleep Timer Circular HUD

- **Deliverable:** Haupt-Playeransicht fuer die Nacht mit kreisfoermigem Countdown-HUD, grossen Tasten und +15 Min Schnellverlaengerung.
- **Blocked by:** TICK-013, TICK-026
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Presentation / Screen
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Grosser kreisfoermiger Restzeit-Indikator mit Fortschrittsanzeige.
  - [ ] One-Tap Schnellverlaengerung um 15 Minuten per grosser Taste.
  - [ ] Anzeige des aktuellen Shake-Profils (Nachttisch / Matratze).
  - [ ] Grosse Play/Pause und 30s Rueckwaerts-Tasten fuer blinde Bedienung.
- **Verifikation:** Flutter Widget Tests

### TICK-028: Bed-Lock Touch-Sperre & Gesten-Steuerung

- **Deliverable:** Vollbild-Touchsperre (Bed Lock) gegen versehentliche Eingaben durch Bettdecke, Kissen oder Beruehrungen im Halbschlaf.
- **Blocked by:** TICK-027
- **Prio / Points:** P1 | 3 Story Points
- **Typ / Schicht:** Feature | Presentation / Lock
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Ein-Klick Aktivierung der Bildschirmsperre im Player.
  - [ ] Deaktiviert alle normalen Touch-Gesten waehrend der Sperre.
  - [ ] Entsperren erfordert bewusste Geste (langes Druecken von 2 Sekunden oder Wischgeste).
  - [ ] Gedaempfte Bildschirmanzeige waehrend Bed-Lock aktiv ist.
- **Verifikation:** Gesture & Lock Widget Tests

### TICK-029: Unified Playback Queue (Audiobuch, Podcast & YouTube)

- **Deliverable:** Einheitliche Abspiel-Warteschlange fuer nahtlose Mischung von lokalen Dateien, Podcast-Folgen und YouTube-Audiotracks.
- **Blocked by:** TICK-004, TICK-012, TICK-023, TICK-025
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Tracer Bullet | Domain & Presentation
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Warteschlange akzeptiert beliebige Kombinationen der unterstuetzten Medientypen.
  - [ ] Automatischer, unterbrechungsfreier Uebergang zum naechsten Track in der Queue.
  - [ ] Reordering (Drag & Drop) und Entfernen von Eintraegen per Wischgeste.
  - [ ] Queue-Zustand wird persistent in Drift-Datenbank gesichert.
- **Verifikation:** Queue Management & State Tests

### TICK-030: Video/Audio Umschalter & Picture-in-Picture (PiP) Modus

- **Deliverable:** Nahtloser Umschalter zwischen reinem Audio- und Videoplayer fuer YouTube-Inhalte inklusive Android Picture-in-Picture Support.
- **Blocked by:** TICK-020, TICK-027
- **Prio / Points:** P2 | 5 Story Points
- **Typ / Schicht:** Feature | Presentation / Video
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Umschalt-Taste wechselt ohne Abspielunterbrechung zwischen Video und Reinaudio.
  - [ ] Video wird bei Verlassen der App oder Home-Geste automatisch im PiP-Fenster gezeigt.
  - [ ] Beim Ausschalten des Bildschirms wird sofort in den akkuschonenden Audio-Modus gewechselt.
  - [ ] Kein Videodecoder-Ressourcenverbrauch im reinen Audio-Modus.
- **Verifikation:** Android PiP Lifecycle Tests

### TICK-031: Library Browser & Suche (Filter nach Autor, Genre, Offline-Status)

- **Deliverable:** Uebersichtliche Medienbibliothek mit Volltextsuche, Sortierung nach Autor/Buch und Filter fuer Offline-Verfuegbarkeit.
- **Blocked by:** TICK-009, TICK-029
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Feature | Presentation / Library
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Schnelle Volltextsuche ueber lokale Hoerbuecher, Podcasts und Downloads.
  - [ ] Filterchips: Alle, Hoerbuecher, Podcasts, YouTube, Nur Offline verfuegbar.
  - [ ] Hierarchische Ansicht: Autor -> Alben/Buecher -> Kapitel/Tracks.
  - [ ] Kontextmenue fuer schnelles Hinzufuegen zur Bedtime-Queue.
- **Verifikation:** Widget & Search Performance Tests

## Phase 6: CI/CD & Testing

### TICK-032: GitHub Actions CI/CD Pipeline & Split APK Signing

- **Deliverable:** Automatisierte CI/CD-Pipeline in GitHub Actions zum Erstellen, Signieren und Veroeffentlichen schlanker Release-APKs.
- **Blocked by:** Keine (Start sofort)
- **Prio / Points:** P0 | 3 Story Points
- **Typ / Schicht:** DevOps | CI/CD & DevOps
- **Status:** `Ready for Dev`
- **Akzeptanzkriterien:**
  - [ ] Automatischer Build von arm64-v8a Split-APK und universal-APK bei Tag-Push.
  - [ ] Signierung mit sicher in GitHub Secrets hinterlegtem Production-Keystore.
  - [ ] Automatische Erstellung von SHA-256 Pruefsummen fuer jedes Artefakt.
  - [ ] Release-Erstellung auf GitHub mit generierten Release-Notes.
- **Verifikation:** GitHub Actions Workflow Dry-Run

### TICK-033: In-App Self-Updater via GitHub Releases API

- **Deliverable:** Integrierter Updater, der GitHub Releases prueft, die passende arm64-v8a APK laedt, Pruefsummen verifiziert und die Installation startet.
- **Blocked by:** TICK-032
- **Prio / Points:** P1 | 5 Story Points
- **Typ / Schicht:** Feature | Platform / Update
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Prueft im Hintergrund auf neuere Versionen ueber die GitHub Releases API.
  - [ ] Erkennt CPU-Architektur des Endgeraets (bevorzugt 18 MB arm64-v8a Split-APK).
  - [ ] Verifiziert SHA-256 Hash der heruntergeladenen Datei vor der Installation.
  - [ ] Startet Android Package-Installer Intent fuer nahtloses Update.
- **Verifikation:** Updater Logic & Hash Verification Tests

### TICK-034: Obtainium Kompatibilitaet & Metadaten-Standardisierung

- **Deliverable:** Optimierung der Release-Struktur fuer automatische Updates ueber den Open-Source App-Manager Obtainium.
- **Blocked by:** TICK-032
- **Prio / Points:** P2 | 2 Story Points
- **Typ / Schicht:** DevOps | Distribution
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Release-Tag-Schema folgt streng vX.Y.Z SemVer-Standard.
  - [ ] APK-Dateinamen sind eindeutig nach Schema Nocturne-vX.Y.Z-arm64-v8a.apk benannt.
  - [ ] Obtainium erkennt neue Versionen, filtert passende APK und installiert fehlerfrei.
  - [ ] Dokumentierte Ein-Klick-Anleitung fuer Endanwender im README.
- **Verifikation:** Obtainium Import & Tracking Test

### TICK-035: Unit- & State-Machine-Testsuite (Timer, Fade & Auto-Rewind)

- **Deliverable:** Vollstaendige Testabdeckung der mathematischen Fade-Funktion, der Timer-Zustaende, des Auto-Rewinds und der Grace-Period.
- **Blocked by:** TICK-013, TICK-014, TICK-015, TICK-018
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Testing | Testing & QA
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Unit-Tests fuer die mathematische Korrektheit der quadratischen Drosselungskurve.
  - [ ] Simulation aller Timer-Uebergaenge (Start, Pause, Reset, Timeout, Grace).
  - [ ] Verifikation des -45s Auto-Rewind Offsets bei Ablauf des Timers.
  - [ ] Mindestens 90% Code-Coverage im Domain- und Timer-Paket.
- **Verifikation:** dart test --coverage

### TICK-036: End-to-End Schlafsimulations- & Schuetteltest (Mock Audio & Sensor)

- **Deliverable:** Automatisierter Integrationstest: Simuliert kompletten 30-Minuten-Einschlafzyklus, Fade-Out, Schuetteln auf Matratze und finalen AudioFocus-Verlust.
- **Blocked by:** TICK-016, TICK-017, TICK-018, TICK-029, TICK-035
- **Prio / Points:** P0 | 5 Story Points
- **Typ / Schicht:** Testing | Testing & QA
- **Status:** `Planned`
- **Akzeptanzkriterien:**
  - [ ] Testdurchlauf simuliert Zeitraffung (Fast-Forward) eines kompletten Nachtzyklus.
  - [ ] Mock-Sensor speist Schuettelbewegungen fuer Profil A und Profil B ein.
  - [ ] Bestaetigung des Bluetooth-Auto-Disconnects (abandonAudioFocus) nach Grace-Period.
  - [ ] Keine Speicherlecks (Memory Leaks) oder offenen WakeLocks nach Testende.
- **Verifikation:** Flutter Integration Test Suite

