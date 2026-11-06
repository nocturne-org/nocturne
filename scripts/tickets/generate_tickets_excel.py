"""
Nocturne Bedtime Audio - Ticket & Excel Generator
Erstellt das hochformatierte Excel-Backlog (docs/tickets/nocturne_tickets.xlsx)
sowie die Markdown-Tickets gemass to-tickets Spezifikation.
Strikte Typografie: Ausnahmslos Standard-ASCII-Minus (-).
"""

import os
from pathlib import Path
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

TICKETS = [
    # Phase 1: Setup & Core Architecture
    {
        "id": "TICK-001",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "Flutter & Android Projekt-Setup mit Clean Architecture Grundgeruest",
        "type": "Foundation",
        "layer": "Platform / Infra",
        "points": 3,
        "priority": "P0",
        "status": "Ready for Dev",
        "blocked_by": "Keine (Start sofort)",
        "deliverable": "Initialisiertes Flutter 3.x Projekt mit Clean Architecture Ordnerstruktur (domain, data, presentation, platform), Flavor-Konfiguration, pubspec.yaml und CI-Build-Faehigkeit.",
        "acceptance_criteria": [
            "Flutter Projekt kompiliert fehlerfrei fuer Android (arm64-v8a und universal).",
            "Ordnerhierarchie lib/domain, lib/data, lib/presentation, lib/platform ist etabliert.",
            "pubspec.yaml enthaelt Core-Dependencies (riverpod, just_audio, drift, sensors_plus).",
            "Linting-Regeln mit flutter_lints und strikten Analyse-Optionen konfiguriert.",
            "Basis-App startet in Emulator oder Testgeraet mit leerem AMOLED-Container."
        ],
        "verification": "CI Build & flutter analyze"
    },
    {
        "id": "TICK-002",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "Domain Core Models & Value Objects (MediaItem, Chapter, Queue)",
        "type": "Tracer Bullet",
        "layer": "Domain Core",
        "points": 3,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-001",
        "deliverable": "Plattformunabhaengige Dart-Domainmodelle fuer MediaItem, MediaType, Chapter, Bookmark, MediaSource und PlaybackPosition ohne Flutter-Abhaengigkeiten.",
        "acceptance_criteria": [
            "MediaItem unterstuetzt Typen: Audiobook, PodcastEpisode, YouTubeAudio, YouTubeVideo.",
            "Chapter-Modell erlaubt hierarchische und lineare Kapitel mit Start- und Endzeitstempeln.",
            "Bookmark speichert Millisekunden-Position, Zeitstempel und optionale Notiz.",
            "Value Objects sind unveraenderlich (immutable) und implementieren Gleichheitstests.",
            "100% Testabdeckung fuer Serialisierung und Validierungslogik in Domain-Tests."
        ],
        "verification": "Unit Tests (dart test)"
    },
    {
        "id": "TICK-003",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "Drift SQLite Datenbankschema & Persistenz-Layer",
        "type": "Foundation",
        "layer": "Data / SQLite",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-002",
        "deliverable": "Lokale SQLite-Datenbank via Drift mit Tabellen fuer media_items, bookmarks, playback_history und sleep_presets sowie typensicheren DAOs.",
        "acceptance_criteria": [
            "Tabellen media_items, bookmarks, playback_history, sleep_presets sind definiert.",
            "Drift DAOs bieten reaktive Streams (watch) und asynchrone CRUD-Methoden.",
            "Millisekunden-genaue Speicherung und Abruf der letzten Abspielposition.",
            "Transaktionale Integritaet bei Batch-Updates (z. B. Ordner-Scan Import).",
            "In-Memory SQLite Unit-Tests verifizieren saemtliche Abfragen und Kaskadierungen."
        ],
        "verification": "Unit Tests mit in-memory SQLite"
    },
    {
        "id": "TICK-004",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "Riverpod State-Management & Dependency-Injection Graph",
        "type": "Foundation",
        "layer": "Presentation / State",
        "points": 3,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-003",
        "deliverable": "Strukturierter Riverpod Provider-Baum zur Entkopplung von UI, Repositories und Platform-Services mit Unterstuetzung fuer Test-Overrides.",
        "acceptance_criteria": [
            "Provider fuer Database, MediaRepository, AudioService und TimerController angelegt.",
            "AsyncNotifier-Muster fuer asynchrone Datenzustaende (Laden, Fehler, Daten).",
            "Ueberschreibbarkeit (Overrides) in Widget-Tests ohne echte Audio-Treiber.",
            "Keine Service-Locator Singletons; vollstaendiges Dependency Injection Schema."
        ],
        "verification": "Riverpod Provider Tests"
    },
    {
        "id": "TICK-005",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "Android Foreground Service & MediaSessionService Binding",
        "type": "Tracer Bullet",
        "layer": "Platform / Audio",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-001",
        "deliverable": "Android MediaSessionService mit FOREGROUND_SERVICE_MEDIA_PLAYBACK, PARTIAL_WAKE_LOCK und Media-Notification fuer unterbrechungsfreie Hintergrundwiedergabe.",
        "acceptance_criteria": [
            "Foreground Service startet zuverlaessig bei Wiedergabebeginn.",
            "Wiedergabe laeuft im Hintergrund bei gesperrtem Bildschirm ohne Doze-Unterbrechung weiter.",
            "System-Benachrichtigung zeigt Titel, Cover, Play/Pause und 15s Spul-Aktionen.",
            "Media3 / MediaSession-Events reagieren auf Headset-Tasten und Bluetooth-Geraete."
        ],
        "verification": "Android Integration Test & Device Run"
    },
    {
        "id": "TICK-006",
        "phase": "Phase 1: Setup & Core Domain",
        "title": "JustAudio Engine Adapter & AudioFocus Manager",
        "type": "Adapter",
        "layer": "Platform / Audio",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-005",
        "deliverable": "Adapter-Schicht um just_audio und audio_session mit Fokus-Handling (Ducking, Pause bei Anruf) und unterbrechungsfreiem Stream-Switching.",
        "acceptance_criteria": [
            "AudioSession ist fuer Media/Speech konfiguriert (AUDIOFOCUS_GAIN).",
            "Automatisches Pausieren bei eingehenden Telefonaten oder transientem Fokusverlust.",
            "Ducking bei Navigations- oder kurzen Hinweistoenen.",
            "Buffer-Management fuer fluessiges Pre-Buffering des naechsten Tracks."
        ],
        "verification": "Audio Focus Unit & Mock Tests"
    },

    # Phase 2: Local Storage & Library
    {
        "id": "TICK-007",
        "phase": "Phase 2: Local Storage & Library",
        "title": "Android Storage Access Framework (SAF) Ordner-Picker & Permissions",
        "type": "Feature",
        "layer": "Platform / Storage",
        "points": 3,
        "priority": "P1",
        "status": "Ready for Dev",
        "blocked_by": "Keine (Start sofort)",
        "deliverable": "Integration des Android Storage Access Frameworks (SAF) zur Auswahl externer Hoerbuch-Verzeichnisse mit persistierten Rechten ueber Neustarts.",
        "acceptance_criteria": [
            "Nutzer kann beliebige Ordner auf internem Speicher oder SD-Karte auswaehlen.",
            "App fordert und speichert takePersistableUriPermission dauerhaft.",
            "Verzeichnis-Berechtigungen bleiben nach Geraeteneustart vollstaendig erhalten.",
            "Fehlertolerante Rueckmeldung, wenn SD-Karte entfernt oder Pfad geloescht wurde."
        ],
        "verification": "Manual Verification & SAF Integration"
    },
    {
        "id": "TICK-008",
        "phase": "Phase 2: Local Storage & Library",
        "title": "Interne App-Sandbox Storage Provider & Dateimanager",
        "type": "Foundation",
        "layer": "Data / Storage",
        "points": 3,
        "priority": "P1",
        "status": "Ready for Dev",
        "blocked_by": "Keine (Start sofort)",
        "deliverable": "Sicherer interner Sandbox-Speicheranbieter (/data/user/0/com.nocturne.audio/files/) fuer Downloads, Cache und Cover-Art.",
        "acceptance_criteria": [
            "Eindeutige Verzeichnis-Pfade fuer audio_downloads, podcast_cache und cover_cache.",
            "Schutz vor Bereinigungs-Apps von Drittanbietern und Android-Systembereinigung.",
            "Automatisches Aufraeumen verwaister Download-Fragmente (.part-Dateien).",
            "Speicherplatz-Pruefung vor grossen Downloads mit Warnung bei Restkapazitaet < 500 MB."
        ],
        "verification": "Unit Tests mit Temp-Verzeichnis"
    },
    {
        "id": "TICK-009",
        "phase": "Phase 2: Local Storage & Library",
        "title": "Rekursiver Library-Scanner & Format-Detektor",
        "type": "Tracer Bullet",
        "layer": "Data & Domain",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-003, TICK-007",
        "deliverable": "Hintergrund-Scanner fuer Audioformate (.mp3, .m4b, .m4a, .flac, .opus) mit Isolate-Traversierung ohne Belastung des UI-Threads.",
        "acceptance_criteria": [
            "Findet alle unterstuetzten Audioformate rekursiv in eingebundenen Pfaden.",
            "Traversierung laeuft in separatem Dart Isolate; UI bleibt konstant bei 60 fps.",
            "Fortschritts-Events (Gescannte Dateien / Gesamtanzahl) an UI uebertragen.",
            "Erkennt Aenderungen, Neuzugaenge und geloeschte Dateien inkrementell."
        ],
        "verification": "Integration Test mit Mock-Verzeichnisbaum"
    },
    {
        "id": "TICK-010",
        "phase": "Phase 2: Local Storage & Library",
        "title": "ID3 & M4B Metadaten- & Kapitel-Parser",
        "type": "Feature",
        "layer": "Data / MediaParser",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-002, TICK-009",
        "deliverable": "Extraktion von ID3v1/ID3v2-Tags und M4B/QuickTime-Atomen (Titel, Autor, Album, Track, Cover, eingebettete Kapitelmarken).",
        "acceptance_criteria": [
            "Extrahiert Titel, Kuenstler/Autor, Album/Buchname, Tracknummer und Jahr.",
            "Liest M4B QuickTime Kapitel-Atome mit sekundengenauen Markierungen aus.",
            "Extrahiert eingebettete Coverbilder und legt sie im Cache-Speicher ab.",
            "Robuster Fallback auf Dateinamen, falls Metadaten beschaedigt oder leer sind."
        ],
        "verification": "Unit Tests mit Test-MP3 und Test-M4B Fixtures"
    },
    {
        "id": "TICK-011",
        "phase": "Phase 2: Local Storage & Library",
        "title": "Smart Library Auto-Organizer (ID3 zu Ordner-Hierarchie)",
        "type": "Feature",
        "layer": "Domain & Storage",
        "points": 5,
        "priority": "P2",
        "status": "Planned",
        "blocked_by": "TICK-010",
        "deliverable": "Automatisches Sortier- und Verschiebe-Werkzeug nach dem Schema: Autor / Buchname / Track - Titel.ext inklusive Duplikaterkennung.",
        "acceptance_criteria": [
            "Erkennt unstrukturierte oder falsch abgelegte Audiodateien in Zielordnern.",
            "Vorschau-Modus (Dry-Run): Zeigt geplante Aenderungen vor Ausfuehrung.",
            "Atomare Verschiebung mit Rollback-Sicherheit bei Dateisystem-Fehlern.",
            "Sanitisierung von Sonderzeichen fuer gueltige Dateisystem-Pfade."
        ],
        "verification": "Unit Tests mit Dateisystem-Fixtures"
    },
    {
        "id": "TICK-012",
        "phase": "Phase 2: Local Storage & Library",
        "title": "Lokales Hoerbuch-Abspiel- & Lesezeichen-System",
        "type": "Tracer Bullet",
        "layer": "Domain & Presentation",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-003, TICK-006, TICK-010",
        "deliverable": "End-to-End Wiedergabe lokaler Hoerbuecher mit Track-Uebergaengen, Kapitelsprung und millisekundengenauem Auto-Resume.",
        "acceptance_criteria": [
            "Nahtlose Wiedergabe von Multi-Track Hoerbuechern und Single-File M4B.",
            "Automatisches Setzen des Fortschrittslesezeichens alle 5 Sekunden und beim Pausieren.",
            "Wiederaufnahme an exakt der gespeicherten Position nach App-Neustart.",
            "Kapitelliste ermoeglicht direktes Anspringen einzelner Abschnitte."
        ],
        "verification": "End-to-End Playback Test"
    },

    # Phase 3: Bedtime Engine & Sensorik
    {
        "id": "TICK-013",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "SleepTimer State-Machine & Core Countdown Engine",
        "type": "Tracer Bullet",
        "layer": "Domain Core",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-002, TICK-004",
        "deliverable": "Reaktive Zustandsmaschine fuer den Schlaftimer mit Zustaenden Inaktiv, Zaehlend, Ausblendend, GracePeriod und Gestoppt.",
        "acceptance_criteria": [
            "Zustandsuebergaenge strikt gemaess Spezifikation abgebildet.",
            "Presets fuer 15, 30, 45, 60 Minuten und 'Bis Kapitelende'.",
            "Sekuendliche Ticks mit Millisekunden-Genauigkeit an Riverpod-State.",
            "Schuettel-Event waehrend Zaehlend verlaengert Timer um konfigurierbare Zeit (+15 Min)."
        ],
        "verification": "State-Machine Unit Tests"
    },
    {
        "id": "TICK-014",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "Quadratisch-Logarithmischer Lautstaerke-Fade-Out (60s Blende)",
        "type": "DSP & Audio",
        "layer": "Domain & Audio",
        "points": 3,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-006, TICK-013",
        "deliverable": "Implementierung der Fade-Out Funktion Volume(t) = Volume_start * (t_rest / 60)^2 fuer die letzten 60 Sekunden der Wiedergabe.",
        "acceptance_criteria": [
            "Fade-Out startet exakt bei Restzeit = 60 Sekunden.",
            "Lautstaerke folgt der quadratischen Kurve ohne akustische Spruenge oder Klicklaute.",
            "Schuetteln waehrend Ausblendend setzt Lautstaerke sofort auf 100% und verlaengert um 15 Min.",
            "Bei Restzeit = 0 wird Lautstaerke auf 0 gesetzt und Zustand GracePeriod betreten."
        ],
        "verification": "Unit & Audio-Ramp Tests"
    },
    {
        "id": "TICK-015",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "120-Sekunden Shake-Grace-Period & Auto-Rewind-Bookmarking",
        "type": "Feature",
        "layer": "Domain & Audio",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-012, TICK-014",
        "deliverable": "120-Sekunden Grace-Period bei Stille mit Auto-Rewind-Lesezeichen 45 Sekunden vor Beginn des Fade-Outs.",
        "acceptance_criteria": [
            "Beim Uebergang zu GracePeriod wird ein Lesezeichen bei Position = Position_fade - 45s gesetzt.",
            "Sensor und WakeLock bleiben fuer genau 120 Sekunden aktiv.",
            "Schuetteln waehrend Grace-Period reaktiviert Wiedergabe mit sanftem Fade-In.",
            "Ohne Schuetteln innerhalb 120s: Uebergang zu Gestoppt, Freigabe aller Ressourcen."
        ],
        "verification": "Timing & State-Machine Unit Tests"
    },
    {
        "id": "TICK-016",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "Accelerometer Shake Detection mit Tiefpassfilter & Haptik",
        "type": "Feature",
        "layer": "Platform / Sensors",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-005, TICK-013",
        "deliverable": "Signalverarbeitung des Beschleunigungssensors via sensors_plus mit Software-Tiefpassfilter und dezentem Haptik-Feedback.",
        "acceptance_criteria": [
            "Filtert kontinuierliche Gravitation und Atembewegungen durch Tiefpassfilter heraus.",
            "Erkennt Vorzeichenwechsel und Beschleunigungsspitzen innerhalb eines 600 ms Fensters.",
            "Dezente Haptik-Bestaetigung (15 ms Vibration), kein Wecken des Bettpartners.",
            "Funktioniert zuverlaessig bei ausgeschaltetem Bildschirm im Hintergrund."
        ],
        "verification": "Sensor Driver Tests mit synthetischen Vektordaten"
    },
    {
        "id": "TICK-017",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "Zweistufiges Sensor-Profil (Nachttisch- vs. Matratzen-Modus)",
        "type": "Feature",
        "layer": "Platform & Domain",
        "points": 3,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-016",
        "deliverable": "Umschaltbare Empfindlichkeitsprofile: Profil A (Nachttisch/Hand, 12 m/s²) und Profil B (Matratze/Kissen, 7.5 m/s²).",
        "acceptance_criteria": [
            "Profil A loest bei Schwellenwert > 12.0 m/s² aus (Schutz vor Erschuetterungen).",
            "Profil B loest sensitiv bei > 7.5 m/s² aus (Kompensation von Schaumstoffdaempfung).",
            "Profil ist in App-Einstellungen und Schnellzugriff im Bedtime-Player umschaltbar.",
            "Status wird persistent in den Nutzereinstellungen gespeichert."
        ],
        "verification": "Unit Tests mit kalibrierten Beschleunigungsdaten"
    },
    {
        "id": "TICK-018",
        "phase": "Phase 3: Bedtime Engine & Sensorik",
        "title": "Whisper Dynamics DSP Audio-Filter & Bluetooth Auto-Disconnect",
        "type": "DSP & Audio",
        "layer": "Platform / Audio",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-006, TICK-015",
        "deliverable": "DSP Dynamik-Kompression (Ratio 4:1, Attack < 10ms, Limiter -3 dBFS), High-Shelf Filter ab 4.5 kHz (-6 dB) und AudioFocus Freigabe.",
        "acceptance_criteria": [
            "Dynamikkompression begrenzt Pegelspitzen von Sprache und Musik auf -3 dBFS.",
            "High-Shelf Cut ab 4.5 kHz daempft Zischlaute bei Nachtlautstaerke (5-10%).",
            "Nach Ablauf der Grace-Period wird abandonAudioFocus() aufgerufen.",
            "Bluetooth-In-Ears wechseln nach Fokusfreigabe selbststaendig in den Standby."
        ],
        "verification": "Audio Buffer DSP Analysis & AudioFocus Check"
    },

    # Phase 4: Streaming & Resolvers
    {
        "id": "TICK-019",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "MediaStreamResolver Abstraktion & Circuit-Breaker Router",
        "type": "Foundation",
        "layer": "Domain & Data",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-002, TICK-006",
        "deliverable": "Generische Resolver-Schnittstelle MediaStreamResolver und Router mit Circuit-Breaker-Pattern fuer automatischen Tier-Failover.",
        "acceptance_criteria": [
            "Interface MediaStreamResolver definiert resolveStream, getMetadata, healthCheck.",
            "Circuit-Breaker schaltet nach 2 Fehlversuchen oder HTTP 403 auf Tier 2 um.",
            "Fallback-Kaskade Tier 1 (Lokal) -> Tier 2 (Invidious) -> Tier 3 (Remote Config).",
            "Statistische Erfolgs- und Latenzmetriken je Resolver-Endpunkt."
        ],
        "verification": "Circuit-Breaker Unit Tests mit Mock-Fehlern"
    },
    {
        "id": "TICK-020",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "Tier 1: YouTube InnerTube Parser Adapter (youtube_explode_dart)",
        "type": "Adapter",
        "layer": "Data / Resolver",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-019",
        "deliverable": "In-App Streaming-Adapter fuer YouTube-Inhalte basierend auf InnerTube-Client mit Entschluesselung von Signatur-Chiffren.",
        "acceptance_criteria": [
            "Extrahiert Audio-Streams und Video-Streams aus regulaeren und Kurz-URLs.",
            "Entschluesselt n-sig Parameter zur Vermeidung von Bandbreitendrosselung.",
            "Liest Metadaten (Titel, Kanal, Dauer, Thumbnail-URL) aus.",
            "Liefert standardisierte Stream-Manifeste an den MediaStreamResolver Router."
        ],
        "verification": "Integration Tests gegen Referenz-Streams"
    },
    {
        "id": "TICK-021",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "Tier 2: Foederierter Invidious & Piped API Failover-Adapter",
        "type": "Adapter",
        "layer": "Data / Resolver",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-019",
        "deliverable": "REST-Client fuer dezentrale Invidious- und Piped-Instanzen als Stufe-2-Fallback bei Bot-Blockaden von Stufe 1.",
        "acceptance_criteria": [
            "Kuratierte Liste oeffentlicher, gesunder Invidious/Piped Instanzen integriert.",
            "Automatischer Health-Check (Ping / Latenz) vor Stream-Abruf.",
            "Nahtlose Bereitstellung des Audiostreams ohne Nutzerinteraktion bei Tier-1-Ausfall.",
            "Timeout-Absicherung (maximal 3,5s pro Instanz) vor Weiterschaltung."
        ],
        "verification": "Mock HTTP Client Tests"
    },
    {
        "id": "TICK-022",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "Tier 3: Dynamic Remote Config Rule Engine (GitHub Raw JSON)",
        "type": "Feature",
        "layer": "Data / Config",
        "points": 3,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-019",
        "deliverable": "Asynchrone Remote-Konfiguration via GitHub Raw JSON zur dynamischen Aktualisierung von Client-Parametern ohne APK-Update.",
        "acceptance_criteria": [
            "Laedt Remote-Config asynchron beim Start der App herunter.",
            "Aktualisiert User-Agents, InnerTube-Client-Versionen und aktive Invidious-Instanzen.",
            "Offline-Cache speichert letzte gueltige Konfiguration persistent.",
            "Kryptografische Signatur- oder Hash-Pruefung gegen Manipulation."
        ],
        "verification": "Remote Config Unit Tests & Fixtures"
    },
    {
        "id": "TICK-023",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "Audio-Only Stream Optimierung (M4A/Opus 128-160 kbps)",
        "type": "Feature",
        "layer": "Domain & Audio",
        "points": 3,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-020",
        "deliverable": "Selektion reiner Audio-Bitstreams (M4A / Opus mit 128-160 kbps) mit 85-90% Bandbreiten- und Akku-Einsparung bei YouTube-Inhalten.",
        "acceptance_criteria": [
            "Filtert Video-Streams vollstaendig heraus, wenn Audio-Modus aktiv ist.",
            "Waehlt den qualitativ besten Audio-Container (Opus 160k oder M4A 128k).",
            "Reduziert Netzwerkdatenverbrauch um mindestens 85% gegenueber 1080p Video.",
            "Buffer-Optimierung fuer schnellen Start innerhalb von 800 ms."
        ],
        "verification": "Network Consumption & Bandwidth Tests"
    },
    {
        "id": "TICK-024",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "Background Offline Download Manager mit Tag-Injektion",
        "type": "Tracer Bullet",
        "layer": "Data & Platform",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-008, TICK-020",
        "deliverable": "Download-Manager fuer Offline-Audio/Video in die interne Sandbox mit automatischer Metadaten- und Cover-Injektion.",
        "acceptance_criteria": [
            "Download-Warteschlange mit Pausieren, Fortsetzen und Abbruch.",
            "Downloads laufen im Android Foreground Service zuverlaessig im Hintergrund.",
            "Injektion gueltiger ID3v2-Tags (Titel, Uploader als Kuenstler, Cover) in MP3/M4A.",
            "Heruntergeladene Dateien erscheinen sofort in der lokalen Bibliothek."
        ],
        "verification": "Download Manager Integration Tests"
    },
    {
        "id": "TICK-025",
        "phase": "Phase 4: Streaming & Resolvers",
        "title": "RSS Podcast Feed Parser & Episode Downloader",
        "type": "Feature",
        "layer": "Domain & Data",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-003, TICK-024",
        "deliverable": "RSS 2.0 / iTunes XML Podcast Feed Parser mit Episodenverwaltung, automatischem Download und Kapitelmarken.",
        "acceptance_criteria": [
            "Parst beliebige RSS-Podcast-URLs gemaess RSS 2.0 und Apple Podcasts DTD.",
            "Extrahiert Episodenliste, Shownotes, Veroeffentlichungsdatum und Audio-Enclosures.",
            "Unterstuetzt Streaming und wahlweisen Offline-Download von Episoden.",
            "Speichert Abonnements und gehoerte Episoden in der lokalen Drift-Datenbank."
        ],
        "verification": "RSS Parser Unit Tests mit Standard-Feeds"
    },

    # Phase 5: UI & Bedtime Player
    {
        "id": "TICK-026",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "AMOLED Pure Black Theme & Bedtime Design System",
        "type": "UI / Design",
        "layer": "Presentation / Theme",
        "points": 3,
        "priority": "P1",
        "status": "Ready for Dev",
        "blocked_by": "Keine (Start sofort)",
        "deliverable": "Design-System mit 100% reinem OLED-Schwarz (#000000), blendfreier Typografie und barrierefreien Touch-Zielen (> 48 dp).",
        "acceptance_criteria": [
            "Hintergruende zu 100% #000000 zur Abschaltung von OLED-Pixeln.",
            "Gedaempfte Akzentfarben (Sanftes Bernstein #F59E0B und Nacht-Cyan #06B6D4).",
            "Keine grellen Weiss-Toene (Texte in gedimmtem Off-White #E2E8F0 und #94A3B8).",
            "Alle interaktiven Touch-Flaechen besitzen mindestens 48x48 dp Abmessung."
        ],
        "verification": "Flutter Widget & Contrast Tests"
    },
    {
        "id": "TICK-027",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "Bedtime Player Screen & Sleep Timer Circular HUD",
        "type": "Tracer Bullet",
        "layer": "Presentation / Screen",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-013, TICK-026",
        "deliverable": "Haupt-Playeransicht fuer die Nacht mit kreisfoermigem Countdown-HUD, grossen Tasten und +15 Min Schnellverlaengerung.",
        "acceptance_criteria": [
            "Grosser kreisfoermiger Restzeit-Indikator mit Fortschrittsanzeige.",
            "One-Tap Schnellverlaengerung um 15 Minuten per grosser Taste.",
            "Anzeige des aktuellen Shake-Profils (Nachttisch / Matratze).",
            "Grosse Play/Pause und 30s Rueckwaerts-Tasten fuer blinde Bedienung."
        ],
        "verification": "Flutter Widget Tests"
    },
    {
        "id": "TICK-028",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "Bed-Lock Touch-Sperre & Gesten-Steuerung",
        "type": "Feature",
        "layer": "Presentation / Lock",
        "points": 3,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-027",
        "deliverable": "Vollbild-Touchsperre (Bed Lock) gegen versehentliche Eingaben durch Bettdecke, Kissen oder Beruehrungen im Halbschlaf.",
        "acceptance_criteria": [
            "Ein-Klick Aktivierung der Bildschirmsperre im Player.",
            "Deaktiviert alle normalen Touch-Gesten waehrend der Sperre.",
            "Entsperren erfordert bewusste Geste (langes Druecken von 2 Sekunden oder Wischgeste).",
            "Gedaempfte Bildschirmanzeige waehrend Bed-Lock aktiv ist."
        ],
        "verification": "Gesture & Lock Widget Tests"
    },
    {
        "id": "TICK-029",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "Unified Playback Queue (Audiobuch, Podcast & YouTube)",
        "type": "Tracer Bullet",
        "layer": "Domain & Presentation",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-004, TICK-012, TICK-023, TICK-025",
        "deliverable": "Einheitliche Abspiel-Warteschlange fuer nahtlose Mischung von lokalen Dateien, Podcast-Folgen und YouTube-Audiotracks.",
        "acceptance_criteria": [
            "Warteschlange akzeptiert beliebige Kombinationen der unterstuetzten Medientypen.",
            "Automatischer, unterbrechungsfreier Uebergang zum naechsten Track in der Queue.",
            "Reordering (Drag & Drop) und Entfernen von Eintraegen per Wischgeste.",
            "Queue-Zustand wird persistent in Drift-Datenbank gesichert."
        ],
        "verification": "Queue Management & State Tests"
    },
    {
        "id": "TICK-030",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "Video/Audio Umschalter & Picture-in-Picture (PiP) Modus",
        "type": "Feature",
        "layer": "Presentation / Video",
        "points": 5,
        "priority": "P2",
        "status": "Planned",
        "blocked_by": "TICK-020, TICK-027",
        "deliverable": "Nahtloser Umschalter zwischen reinem Audio- und Videoplayer fuer YouTube-Inhalte inklusive Android Picture-in-Picture Support.",
        "acceptance_criteria": [
            "Umschalt-Taste wechselt ohne Abspielunterbrechung zwischen Video und Reinaudio.",
            "Video wird bei Verlassen der App oder Home-Geste automatisch im PiP-Fenster gezeigt.",
            "Beim Ausschalten des Bildschirms wird sofort in den akkuschonenden Audio-Modus gewechselt.",
            "Kein Videodecoder-Ressourcenverbrauch im reinen Audio-Modus."
        ],
        "verification": "Android PiP Lifecycle Tests"
    },
    {
        "id": "TICK-031",
        "phase": "Phase 5: UI & Bedtime Player",
        "title": "Library Browser & Suche (Filter nach Autor, Genre, Offline-Status)",
        "type": "Feature",
        "layer": "Presentation / Library",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-009, TICK-029",
        "deliverable": "Uebersichtliche Medienbibliothek mit Volltextsuche, Sortierung nach Autor/Buch und Filter fuer Offline-Verfuegbarkeit.",
        "acceptance_criteria": [
            "Schnelle Volltextsuche ueber lokale Hoerbuecher, Podcasts und Downloads.",
            "Filterchips: Alle, Hoerbuecher, Podcasts, YouTube, Nur Offline verfuegbar.",
            "Hierarchische Ansicht: Autor -> Alben/Buecher -> Kapitel/Tracks.",
            "Kontextmenue fuer schnelles Hinzufuegen zur Bedtime-Queue."
        ],
        "verification": "Widget & Search Performance Tests"
    },

    # Phase 6: CI/CD, Distribution & Testing
    {
        "id": "TICK-032",
        "phase": "Phase 6: CI/CD & Testing",
        "title": "GitHub Actions CI/CD Pipeline & Split APK Signing",
        "type": "DevOps",
        "layer": "CI/CD & DevOps",
        "points": 3,
        "priority": "P0",
        "status": "Ready for Dev",
        "blocked_by": "Keine (Start sofort)",
        "deliverable": "Automatisierte CI/CD-Pipeline in GitHub Actions zum Erstellen, Signieren und Veroeffentlichen schlanker Release-APKs.",
        "acceptance_criteria": [
            "Automatischer Build von arm64-v8a Split-APK und universal-APK bei Tag-Push.",
            "Signierung mit sicher in GitHub Secrets hinterlegtem Production-Keystore.",
            "Automatische Erstellung von SHA-256 Pruefsummen fuer jedes Artefakt.",
            "Release-Erstellung auf GitHub mit generierten Release-Notes."
        ],
        "verification": "GitHub Actions Workflow Dry-Run"
    },
    {
        "id": "TICK-033",
        "phase": "Phase 6: CI/CD & Testing",
        "title": "In-App Self-Updater via GitHub Releases API",
        "type": "Feature",
        "layer": "Platform / Update",
        "points": 5,
        "priority": "P1",
        "status": "Planned",
        "blocked_by": "TICK-032",
        "deliverable": "Integrierter Updater, der GitHub Releases prueft, die passende arm64-v8a APK laedt, Pruefsummen verifiziert und die Installation startet.",
        "acceptance_criteria": [
            "Prueft im Hintergrund auf neuere Versionen ueber die GitHub Releases API.",
            "Erkennt CPU-Architektur des Endgeraets (bevorzugt 18 MB arm64-v8a Split-APK).",
            "Verifiziert SHA-256 Hash der heruntergeladenen Datei vor der Installation.",
            "Startet Android Package-Installer Intent fuer nahtloses Update."
        ],
        "verification": "Updater Logic & Hash Verification Tests"
    },
    {
        "id": "TICK-034",
        "phase": "Phase 6: CI/CD & Testing",
        "title": "Obtainium Kompatibilitaet & Metadaten-Standardisierung",
        "type": "DevOps",
        "layer": "Distribution",
        "points": 2,
        "priority": "P2",
        "status": "Planned",
        "blocked_by": "TICK-032",
        "deliverable": "Optimierung der Release-Struktur fuer automatische Updates ueber den Open-Source App-Manager Obtainium.",
        "acceptance_criteria": [
            "Release-Tag-Schema folgt streng vX.Y.Z SemVer-Standard.",
            "APK-Dateinamen sind eindeutig nach Schema Nocturne-vX.Y.Z-arm64-v8a.apk benannt.",
            "Obtainium erkennt neue Versionen, filtert passende APK und installiert fehlerfrei.",
            "Dokumentierte Ein-Klick-Anleitung fuer Endanwender im README."
        ],
        "verification": "Obtainium Import & Tracking Test"
    },
    {
        "id": "TICK-035",
        "phase": "Phase 6: CI/CD & Testing",
        "title": "Unit- & State-Machine-Testsuite (Timer, Fade & Auto-Rewind)",
        "type": "Testing",
        "layer": "Testing & QA",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-013, TICK-014, TICK-015, TICK-018",
        "deliverable": "Vollstaendige Testabdeckung der mathematischen Fade-Funktion, der Timer-Zustaende, des Auto-Rewinds und der Grace-Period.",
        "acceptance_criteria": [
            "Unit-Tests fuer die mathematische Korrektheit der quadratischen Drosselungskurve.",
            "Simulation aller Timer-Uebergaenge (Start, Pause, Reset, Timeout, Grace).",
            "Verifikation des -45s Auto-Rewind Offsets bei Ablauf des Timers.",
            "Mindestens 90% Code-Coverage im Domain- und Timer-Paket."
        ],
        "verification": "dart test --coverage"
    },
    {
        "id": "TICK-036",
        "phase": "Phase 6: CI/CD & Testing",
        "title": "End-to-End Schlafsimulations- & Schuetteltest (Mock Audio & Sensor)",
        "type": "Testing",
        "layer": "Testing & QA",
        "points": 5,
        "priority": "P0",
        "status": "Planned",
        "blocked_by": "TICK-016, TICK-017, TICK-018, TICK-029, TICK-035",
        "deliverable": "Automatisierter Integrationstest: Simuliert kompletten 30-Minuten-Einschlafzyklus, Fade-Out, Schuetteln auf Matratze und finalen AudioFocus-Verlust.",
        "acceptance_criteria": [
            "Testdurchlauf simuliert Zeitraffung (Fast-Forward) eines kompletten Nachtzyklus.",
            "Mock-Sensor speist Schuettelbewegungen fuer Profil A und Profil B ein.",
            "Bestaetigung des Bluetooth-Auto-Disconnects (abandonAudioFocus) nach Grace-Period.",
            "Keine Speicherlecks (Memory Leaks) oder offenen WakeLocks nach Testende."
        ],
        "verification": "Flutter Integration Test Suite"
    }
]

PHASES_META = [
    {
        "name": "Phase 1: Setup & Core Domain",
        "theme": "0284C7", # Sky Blue
        "goal": "Kompilierbares Clean Architecture Grundgeruest, Domain-Modelle, SQLite-Persistenz und Android MediaSessionService.",
        "tickets": "TICK-001 bis TICK-006",
        "exit_criteria": "Android App spielt lokalen Test-Audiofile im Hintergrund bei gesperrtem Bildschirm ab."
    },
    {
        "name": "Phase 2: Local Storage & Library",
        "theme": "059669", # Emerald
        "goal": "SAF Ordner-Picker, rekursiver Scanner, ID3/M4B Kapitel-Parser, Auto-Organizer und Lesezeichen-System.",
        "tickets": "TICK-007 bis TICK-012",
        "exit_criteria": "Beliebiger lokaler Hoerbuch-Ordner wird gescannt, sortiert und mit Kapiteln fortsetzbar abgespielt."
    },
    {
        "name": "Phase 3: Bedtime Engine & Sensorik",
        "theme": "7C3AED", # Violet
        "goal": "Schlaftimer State-Machine, quadratischer Fade-Out, 120s Grace-Period, Schuettel-Sensor mit Dual-Profil und Whisper-Dynamics DSP.",
        "tickets": "TICK-013 bis TICK-018",
        "exit_criteria": "Timer blendet Audio in 60s lautlos aus, Schuetteln im Bett reaktiviert Wiedergabe mit sanftem Fade-In."
    },
    {
        "name": "Phase 4: Streaming & Resolvers",
        "theme": "D97706", # Amber
        "goal": "Pluggable 3-Tier MediaStreamResolver (InnerTube, Invidious, GitHub Raw Remote Config), YouTube Audio-Only und RSS Podcasts.",
        "tickets": "TICK-019 bis TICK-025",
        "exit_criteria": "YouTube-Audios und RSS-Podcasts werden direkt gestreamt oder offline in Sandbox gespeichert."
    },
    {
        "name": "Phase 5: UI & Bedtime Player",
        "theme": "DB2777", # Pink / Rose
        "goal": "Reines OLED-Schwarz Theme (#000000), kreisfoermiges Bedtime-HUD, Bed-Lock Touch-Sperre, Unified Queue und Mediensuche.",
        "tickets": "TICK-026 bis TICK-031",
        "exit_criteria": "Blendfreie Nachttisch-UI ermoeglicht fehlerfreie Bedienung im Halbdunkel mit Tastensperre."
    },
    {
        "name": "Phase 6: CI/CD & Testing",
        "theme": "4B5563", # Slate Gray
        "goal": "Automatisierte GitHub Actions Pipeline fuer Split-APKs, In-App Self-Updater, Obtainium Support und End-to-End Simulation.",
        "tickets": "TICK-032 bis TICK-036",
        "exit_criteria": "Release-APK wird automatisch gebaut, signiert und ueber den In-App Updater fehlerfrei aktualisiert."
    }
]

def build_excel(output_path: Path):
    wb = openpyxl.Workbook()
    
    # -------------------------------------------------------------
    # Styling Palettes & Definitions
    # -------------------------------------------------------------
    font_family = "Segoe UI"
    
    title_font = Font(name=font_family, size=16, bold=True, color="FFFFFF")
    section_font = Font(name=font_family, size=12, bold=True, color="0F172A")
    header_font = Font(name=font_family, size=10, bold=True, color="FFFFFF")
    data_font = Font(name=font_family, size=9, bold=False, color="1E293B")
    data_bold = Font(name=font_family, size=9, bold=True, color="0F172A")
    kpi_val_font = Font(name=font_family, size=20, bold=True, color="0F172A")
    kpi_sub_font = Font(name=font_family, size=8, bold=False, color="64748B")
    
    thin_border = Border(
        left=Side(style='thin', color='E2E8F0'),
        right=Side(style='thin', color='E2E8F0'),
        top=Side(style='thin', color='E2E8F0'),
        bottom=Side(style='thin', color='E2E8F0')
    )
    
    header_fill = PatternFill(start_color="0F172A", end_color="0F172A", fill_type="solid")
    accent_bar_fill = PatternFill(start_color="1E293B", end_color="1E293B", fill_type="solid")
    kpi_fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    zebra_fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    white_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")
    
    # Priority Styles
    p_styles = {
        "P0": {"fill": PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid"), "font": Font(name=font_family, size=9, bold=True, color="991B1B")},
        "P1": {"fill": PatternFill(start_color="FFEDD5", end_color="FFEDD5", fill_type="solid"), "font": Font(name=font_family, size=9, bold=True, color="9A3412")},
        "P2": {"fill": PatternFill(start_color="E0F2FE", end_color="E0F2FE", fill_type="solid"), "font": Font(name=font_family, size=9, bold=True, color="075985")},
        "P3": {"fill": PatternFill(start_color="F3F4F6", end_color="F3F4F6", fill_type="solid"), "font": Font(name=font_family, size=9, bold=False, color="374151")},
    }
    
    # Status Styles
    s_styles = {
        "Ready for Dev": {"fill": PatternFill(start_color="DCFCE7", end_color="DCFCE7", fill_type="solid"), "font": Font(name=font_family, size=9, bold=True, color="166534")},
        "Planned": {"fill": PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid"), "font": Font(name=font_family, size=9, bold=False, color="475569")},
    }
    
    # =============================================================
    # SHEET 1: Uebersicht & KPIs
    # =============================================================
    ws1 = wb.active
    ws1.title = "Uebersicht & KPIs"
    ws1.views.sheetView[0].showGridLines = True
    
    # Title Banner
    ws1.merge_cells("A1:H2")
    t_cell = ws1["A1"]
    t_cell.value = "  NOCTURNE - BEDTIME AUDIO ENGINE | PROJEKT-BACKLOG & TRACKING"
    t_cell.font = title_font
    t_cell.fill = header_fill
    t_cell.alignment = Alignment(vertical="center", horizontal="left")
    
    # Subtitle / Metadata
    ws1["A3"] = "Version: 1.0.0 | Architektur: Clean Architecture (Dart/Flutter) | Ziel-Plattform: Android APK (Sideload / Obtainium)"
    ws1["A3"].font = Font(name=font_family, size=9, italic=True, color="64748B")
    
    # KPI Cards (Row 5 to 7)
    kpis = [
        ("B5:B7", "Gesamt-Tickets", "=COUNTA('Tickets (Backlog)'!A3:A38)", "Tracer-Bullet Einheiten"),
        ("D5:D7", "Story Points Gesamt", "=SUM('Tickets (Backlog)'!G3:G38)", "Gesamter Entwicklungsaufwand"),
        ("F5:F7", "Sofort Startbar", "=COUNTIF('Tickets (Backlog)'!I3:I38, \"Ready for Dev\")", "Frontier Tickets (Unblockiert)"),
        ("H5:H7", "Kritischer Pfad (P0)", "=COUNTIF('Tickets (Backlog)'!H3:H38, \"P0\")", "Essentielle Kern-Tickets")
    ]
    
    for pos, label, formula, note in kpis:
        c_from, c_to = pos.split(":")
        col_letter = c_from[0]
        r_top = int(c_from[1])
        r_val = r_top + 1
        r_sub = r_top + 2
        
        c_lbl = ws1[f"{col_letter}{r_top}"]
        c_lbl.value = label
        c_lbl.font = Font(name=font_family, size=8, bold=True, color="475569")
        c_lbl.alignment = Alignment(horizontal="center", vertical="center")
        c_lbl.fill = kpi_fill
        c_lbl.border = thin_border
        
        c_val = ws1[f"{col_letter}{r_val}"]
        c_val.value = formula
        c_val.font = kpi_val_font
        c_val.alignment = Alignment(horizontal="center", vertical="center")
        c_val.fill = kpi_fill
        c_val.border = thin_border
        
        c_sub = ws1[f"{col_letter}{r_sub}"]
        c_sub.value = note
        c_sub.font = kpi_sub_font
        c_sub.alignment = Alignment(horizontal="center", vertical="center")
        c_sub.fill = kpi_fill
        c_sub.border = thin_border
    
    # Phase Breakdown Table (Row 9+)
    ws1["A9"] = "PHASEN-VERTEILUNG & AUFWANDSSCHAETZUNG"
    ws1["A9"].font = section_font
    
    phase_headers = ["Phase", "Tickets", "Story Points", "Fokus & Kernziel", "Exit-Kriterium"]
    for col_idx, h_text in enumerate(phase_headers, start=1):
        cell = ws1.cell(row=10, column=col_idx, value=h_text)
        cell.font = header_font
        cell.fill = accent_bar_fill
        cell.alignment = Alignment(horizontal="center" if col_idx in [2, 3] else "left", vertical="center")
        cell.border = thin_border
    
    for idx, p in enumerate(PHASES_META, start=11):
        row_fill = zebra_fill if idx % 2 == 0 else white_fill
        
        c1 = ws1.cell(row=idx, column=1, value=p["name"])
        c1.font = data_bold
        c1.fill = row_fill
        c1.border = thin_border
        
        c2 = ws1.cell(row=idx, column=2, value=f"=COUNTIF('Tickets (Backlog)'!B$3:B$38, \"{p['name']}\")")
        c2.font = data_bold
        c2.alignment = Alignment(horizontal="center")
        c2.fill = row_fill
        c2.border = thin_border
        
        c3 = ws1.cell(row=idx, column=3, value=f"=SUMIFS('Tickets (Backlog)'!G$3:G$38, 'Tickets (Backlog)'!B$3:B$38, \"{p['name']}\")")
        c3.font = data_bold
        c3.alignment = Alignment(horizontal="center")
        c3.fill = row_fill
        c3.border = thin_border
        
        c4 = ws1.cell(row=idx, column=4, value=p["goal"])
        c4.font = data_font
        c4.fill = row_fill
        c4.border = thin_border
        
        c5 = ws1.cell(row=idx, column=5, value=p["exit_criteria"])
        c5.font = data_font
        c5.fill = row_fill
        c5.border = thin_border
        
    # Total row for phases
    tot_row = 11 + len(PHASES_META)
    ws1.cell(row=tot_row, column=1, value="Gesamtsumme").font = data_bold
    ws1.cell(row=tot_row, column=1).fill = kpi_fill
    ws1.cell(row=tot_row, column=1).border = thin_border
    
    t_c2 = ws1.cell(row=tot_row, column=2, value=f"=SUM(B11:B{tot_row-1})")
    t_c2.font = data_bold
    t_c2.alignment = Alignment(horizontal="center")
    t_c2.fill = kpi_fill
    t_c2.border = thin_border
    
    t_c3 = ws1.cell(row=tot_row, column=3, value=f"=SUM(C11:C{tot_row-1})")
    t_c3.font = data_bold
    t_c3.alignment = Alignment(horizontal="center")
    t_c3.fill = kpi_fill
    t_c3.border = thin_border
    
    ws1.cell(row=tot_row, column=4, value="Vollstaendige Abdeckung aller Anforderungen").font = Font(name=font_family, size=9, italic=True)
    ws1.cell(row=tot_row, column=4).fill = kpi_fill
    ws1.cell(row=tot_row, column=4).border = thin_border
    
    ws1.cell(row=tot_row, column=5, value="Release-Faehige App").font = Font(name=font_family, size=9, italic=True)
    ws1.cell(row=tot_row, column=5).fill = kpi_fill
    ws1.cell(row=tot_row, column=5).border = thin_border

    # Priority Summary Box (Row 19+)
    ws1["A19"] = "PRIORITAETEN-VERTEILUNG"
    ws1["A19"].font = section_font
    
    prio_headers = ["Prioritaet", "Bedeutung", "Anzahl Tickets", "Anteil"]
    for c_idx, h in enumerate(prio_headers, start=1):
        c = ws1.cell(row=20, column=c_idx, value=h)
        c.font = header_font
        c.fill = accent_bar_fill
        c.alignment = Alignment(horizontal="center" if c_idx in [3, 4] else "left", vertical="center")
        c.border = thin_border
        
    prio_rows = [
        ("P0", "Blocker / Must Have (Kritischer Pfad fuer Mindestfunktion)", "red"),
        ("P1", "High Priority (Wesentliche Kernfunktionen & Ergonomie)", "orange"),
        ("P2", "Normal (Komfortfunktionen & erweiterte Umschalter)", "blue"),
        ("P3", "Low (Optionale Nischen-Features)", "gray")
    ]
    
    for r_idx, (p_code, p_desc, col_tag) in enumerate(prio_rows, start=21):
        c1 = ws1.cell(row=r_idx, column=1, value=p_code)
        c1.font = p_styles[p_code]["font"]
        c1.fill = p_styles[p_code]["fill"]
        c1.alignment = Alignment(horizontal="center")
        c1.border = thin_border
        
        c2 = ws1.cell(row=r_idx, column=2, value=p_desc)
        c2.font = data_font
        c2.fill = white_fill
        c2.border = thin_border
        
        c3 = ws1.cell(row=r_idx, column=3, value=f"=COUNTIF('Tickets (Backlog)'!H$3:H$38, \"{p_code}\")")
        c3.font = data_bold
        c3.alignment = Alignment(horizontal="center")
        c3.fill = white_fill
        c3.border = thin_border
        
        c4 = ws1.cell(row=r_idx, column=4, value=f"=C{r_idx}/B$7")
        c4.number_format = "0.0%"
        c4.font = data_bold
        c4.alignment = Alignment(horizontal="center")
        c4.fill = white_fill
        c4.border = thin_border
        
    ws1.column_dimensions['A'].width = 30
    ws1.column_dimensions['B'].width = 16
    ws1.column_dimensions['C'].width = 16
    ws1.column_dimensions['D'].width = 45
    ws1.column_dimensions['E'].width = 50
    ws1.column_dimensions['F'].width = 18
    ws1.column_dimensions['G'].width = 18
    ws1.column_dimensions['H'].width = 24

    # =============================================================
    # SHEET 2: Tickets (Backlog)
    # =============================================================
    ws2 = wb.create_sheet(title="Tickets (Backlog)")
    ws2.views.sheetView[0].showGridLines = True
    
    headers = [
        "Ticket-ID",
        "Phase / Epic",
        "Titel der Aufgabe",
        "Typ",
        "Schicht (Layer)",
        "Was gebaut wird (Deliverable / End-to-End)",
        "Points",
        "Prio",
        "Status",
        "Blockiert durch (Dependencies)",
        "Akzeptanzkriterien",
        "Verifikationsmethode"
    ]
    
    # Title in row 1
    ws2.merge_cells("A1:L1")
    head_banner = ws2["A1"]
    head_banner.value = "  NOCTURNE - VOLLSTAENDIGES SPRINT- & ENTWICKLUNGS-BACKLOG (36 TRACER-BULLET TICKETS)"
    head_banner.font = Font(name=font_family, size=11, bold=True, color="FFFFFF")
    head_banner.fill = header_fill
    head_banner.alignment = Alignment(vertical="center", horizontal="left")
    
    # Table Header in row 2
    for col_idx, h in enumerate(headers, start=1):
        cell = ws2.cell(row=2, column=col_idx, value=h)
        cell.font = header_font
        cell.fill = accent_bar_fill
        cell.border = thin_border
        cell.alignment = Alignment(
            horizontal="center" if col_idx in [1, 4, 7, 8, 9] else "left",
            vertical="center",
            wrap_text=True
        )
    
    # Fill tickets
    for r_idx, t in enumerate(TICKETS, start=3):
        is_even = (r_idx % 2 == 0)
        base_fill = zebra_fill if is_even else white_fill
        
        # A: ID
        c_id = ws2.cell(row=r_idx, column=1, value=t["id"])
        c_id.font = data_bold
        c_id.alignment = Alignment(horizontal="center", vertical="top")
        c_id.fill = base_fill
        c_id.border = thin_border
        
        # B: Phase
        c_phase = ws2.cell(row=r_idx, column=2, value=t["phase"])
        c_phase.font = data_bold
        c_phase.alignment = Alignment(horizontal="left", vertical="top")
        c_phase.fill = base_fill
        c_phase.border = thin_border
        
        # C: Title
        c_title = ws2.cell(row=r_idx, column=3, value=t["title"])
        c_title.font = data_bold
        c_title.alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
        c_title.fill = base_fill
        c_title.border = thin_border
        
        # D: Typ
        c_type = ws2.cell(row=r_idx, column=4, value=t["type"])
        c_type.font = data_font
        c_type.alignment = Alignment(horizontal="center", vertical="top")
        c_type.fill = base_fill
        c_type.border = thin_border
        
        # E: Layer
        c_layer = ws2.cell(row=r_idx, column=5, value=t["layer"])
        c_layer.font = data_font
        c_layer.alignment = Alignment(horizontal="left", vertical="top")
        c_layer.fill = base_fill
        c_layer.border = thin_border
        
        # F: Deliverable
        c_deliv = ws2.cell(row=r_idx, column=6, value=t["deliverable"])
        c_deliv.font = data_font
        c_deliv.alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
        c_deliv.fill = base_fill
        c_deliv.border = thin_border
        
        # G: Points
        c_pts = ws2.cell(row=r_idx, column=7, value=t["points"])
        c_pts.font = data_bold
        c_pts.alignment = Alignment(horizontal="center", vertical="top")
        c_pts.fill = base_fill
        c_pts.border = thin_border
        
        # H: Priority
        c_prio = ws2.cell(row=r_idx, column=8, value=t["priority"])
        c_prio.font = p_styles[t["priority"]]["font"]
        c_prio.fill = p_styles[t["priority"]]["fill"]
        c_prio.alignment = Alignment(horizontal="center", vertical="top")
        c_prio.border = thin_border
        
        # I: Status
        c_status = ws2.cell(row=r_idx, column=9, value=t["status"])
        c_status.font = s_styles[t["status"]]["font"]
        c_status.fill = s_styles[t["status"]]["fill"]
        c_status.alignment = Alignment(horizontal="center", vertical="top")
        c_status.border = thin_border
        
        # J: Blocked by
        c_dep = ws2.cell(row=r_idx, column=10, value=t["blocked_by"])
        c_dep.font = data_font
        c_dep.alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
        c_dep.fill = base_fill
        c_dep.border = thin_border
        
        # K: Acceptance Criteria
        ac_text = "\n".join([f"- [ ] {ac}" for ac in t["acceptance_criteria"]])
        c_ac = ws2.cell(row=r_idx, column=11, value=ac_text)
        c_ac.font = data_font
        c_ac.alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
        c_ac.fill = base_fill
        c_ac.border = thin_border
        
        # L: Verification
        c_ver = ws2.cell(row=r_idx, column=12, value=t["verification"])
        c_ver.font = data_font
        c_ver.alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
        c_ver.fill = base_fill
        c_ver.border = thin_border

    # Set Column widths
    col_widths = {
        'A': 12, # ID
        'B': 24, # Phase
        'C': 34, # Title
        'D': 15, # Type
        'E': 18, # Layer
        'F': 48, # Deliverable
        'G': 8,  # Points
        'H': 8,  # Prio
        'I': 15, # Status
        'J': 26, # Blocked By
        'K': 55, # Acceptance Criteria
        'L': 25  # Verification
    }
    for col_let, w in col_widths.items():
        ws2.column_dimensions[col_let].width = w
        
    # AutoFilter and Freeze Panes
    ws2.auto_filter.ref = f"A2:L{len(TICKETS) + 2}"
    ws2.freeze_panes = "C3"

    # =============================================================
    # SHEET 3: Phasen & Roadmap
    # =============================================================
    ws3 = wb.create_sheet(title="Phasen & Roadmap")
    ws3.views.sheetView[0].showGridLines = True
    
    ws3.merge_cells("A1:F1")
    r_banner = ws3["A1"]
    r_banner.value = "  ENTWICKLUNGS-ROADMAP & SEQUENZIERUNG ENTLANG DES KRITISCHEN PFADS"
    r_banner.font = Font(name=font_family, size=11, bold=True, color="FFFFFF")
    r_banner.fill = header_fill
    r_banner.alignment = Alignment(vertical="center", horizontal="left")
    
    roadmap_headers = ["Phase", "Fokus-Bereich", "Tickets", "Geschaetzter Aufwand", "Kern-Deliverable", "Voraussetzung (Eintritt)"]
    for col_idx, h in enumerate(roadmap_headers, start=1):
        cell = ws3.cell(row=2, column=col_idx, value=h)
        cell.font = header_font
        cell.fill = accent_bar_fill
        cell.border = thin_border
        cell.alignment = Alignment(horizontal="center" if col_idx in [3, 4] else "left", vertical="center")
        
    roadmap_data = [
        ("Phase 1: Setup & Core Domain", "Basis-Architektur & Hintergrund-Audio", "TICK-001 bis TICK-006", "24 Story Points", "Android MediaSessionService mit persistenter Drift SQLite DB", "Keine (Projektstart)"),
        ("Phase 2: Local Storage & Library", "Hintergrund-Scanner & Organizer", "TICK-007 bis TICK-012", "26 Story Points", "SAF Ordner-Import mit ID3-Parser und Auto-Sortierung", "Phase 1 abgeschlossen"),
        ("Phase 3: Bedtime Engine & Sensorik", "Akustische & Sensorische Ergonomie", "TICK-013 bis TICK-018", "26 Story Points", "60s quadratischer Fade-Out, 120s Grace, Schuettel-Reset", "AudioService & Timer lauffaehig"),
        ("Phase 4: Streaming & Resolvers", "3-Tier Resolver & Podcast/YouTube", "TICK-019 bis TICK-025", "29 Story Points", "Resiliente InnerTube/Invidious Pipeline + Offline Manager", "Domain Core & Sandbox bereit"),
        ("Phase 5: UI & Bedtime Player", "Nacht-Interface & Touch-Guard", "TICK-026 bis TICK-031", "26 Story Points", "100% OLED Theme, circular HUD, Bed-Lock, Unified Queue", "Bedtime Engine & Player lauffaehig"),
        ("Phase 6: CI/CD & Testing", "Qualitaetssicherung & Distribution", "TICK-032 bis TICK-036", "20 Story Points", "GitHub Actions APK Build, In-App Updater, E2E-Nachtsimulation", "Saemtliche Features implementiert")
    ]
    
    for r_idx, row_vals in enumerate(roadmap_data, start=3):
        r_fill = zebra_fill if r_idx % 2 == 0 else white_fill
        for c_idx, val in enumerate(row_vals, start=1):
            c = ws3.cell(row=r_idx, column=c_idx, value=val)
            c.font = data_bold if c_idx in [1, 3] else data_font
            c.fill = r_fill
            c.border = thin_border
            c.alignment = Alignment(horizontal="center" if c_idx in [3, 4] else "left", vertical="center")
            
    # Critical Path Notes below table
    ws3["A11"] = "ANALYSE DES KRITISCHEN PFADS (CRITICAL PATH):"
    ws3["A11"].font = section_font
    
    crit_path_notes = [
        "1. Pfad A (Audio Core): TICK-001 -> TICK-005 -> TICK-006 -> TICK-014 -> TICK-018 (DSP & Fokusfreigabe).",
        "2. Pfad B (Bedtime Logic): TICK-002 -> TICK-013 -> TICK-014 -> TICK-015 -> TICK-035 (Timer & Auto-Rewind).",
        "3. Pfad C (Streaming Engine): TICK-002 -> TICK-019 -> TICK-020 -> TICK-023 -> TICK-029 (YouTube Audio-Only Queue).",
        "4. Pfad D (Final Gate): TICK-035 (Unit-Tests) + TICK-036 (End-to-End Simulation) bilden das finale Qualitaetssiegel."
    ]
    
    for idx, note in enumerate(crit_path_notes, start=12):
        cell = ws3.cell(row=idx, column=1, value=note)
        cell.font = data_font
        ws3.merge_cells(start_row=idx, start_column=1, end_row=idx, end_column=6)

    ws3.column_dimensions['A'].width = 30
    ws3.column_dimensions['B'].width = 35
    ws3.column_dimensions['C'].width = 22
    ws3.column_dimensions['D'].width = 22
    ws3.column_dimensions['E'].width = 50
    ws3.column_dimensions['F'].width = 28

    # =============================================================
    # SHEET 4: DoD & Governance
    # =============================================================
    ws4 = wb.create_sheet(title="DoD & Governance")
    ws4.views.sheetView[0].showGridLines = True
    
    ws4.merge_cells("A1:E1")
    g_banner = ws4["A1"]
    g_banner.value = "  DEFINITION OF DONE (DOD), ENTWICKLUNGSRICHTLINIEN & COMPLIANCE"
    g_banner.font = Font(name=font_family, size=11, bold=True, color="FFFFFF")
    g_banner.fill = header_fill
    g_banner.alignment = Alignment(vertical="center", horizontal="left")
    
    dod_sections = [
        ("1. DEFINITION OF DONE (DOD) JE TICKET", [
            ("Architektur-Konformitaet", "Code haelt sich strikt an Clean Architecture. Domain-Code enthaelt 0 Flutter/Android Imports."),
            ("Test-Abdeckung", "Jede neue Geschaeftslogik besitzt begleitende Unit- oder Integrationstests. Minimum: 85% Domain-Coverage."),
            ("Static Analysis & Linter", "flutter analyze und dart analyze laufen mit 0 Fehlern und 0 Warnungen durch."),
            ("Typografie-Pflicht", "Ausnahmslos Standard-ASCII-Minus (-). Keine En-Dashes oder Em-Dashes in Code, Doku oder Kommentaren."),
            ("Reversibilitaet", "Jeder Arbeitsblock sichert vorab einen Git-Checkpoint (git branch checkpoint-<timestamp>).")
        ]),
        ("2. ERGONOMISCHE SPEZIFIKATIONEN (BEDTIME ENGINE)", [
            ("Quadratischer Fade-Out", "Volume(t) = Volume_start * (t_rest / 60)^2 in den letzten 60 Sekunden."),
            ("120s Shake Grace Period", "Sensor und WakeLock bleiben 2 Minuten nach Audio=0 aktiv; Schuetteln reaktiviert mit sanftem Fade-In."),
            ("Auto-Rewind Bookmarking", "Automatisches Lesezeichen exakt 45 Sekunden VOR Beginn des Fade-Outs."),
            ("Whisper Dynamics DSP", "Dynamik-Kompression 4:1 mit <10ms Attack und Limiter -3 dBFS. High-Shelf Cut ab 4.5 kHz (-6 dB).")
        ]),
        ("3. RECHTLICHE LEITPLANKEN & VERTRIEB (COMPLIANCE)", [
            ("Schutz vor Takedowns", "Keine Markennamen im Paketnamen (com.nocturne.audio). Neutrale Bezeichnung: Bedtime Audio Engine."),
            ("Kein DRM-Bypass", "Keine Umgehung wirksamer technischer Schutzmassnahmen. Reine Nutzung freier Streams und oeffentlicher Podcasts."),
            ("Gesetzliche Privatkopie", "Gedeckt durch Paragraph 53 dUrhG (Deutschland) und Paragraph 42 oeUrhG (Oesterreich)."),
            ("Vertriebsweg", "Direkt-Vertrieb ueber GitHub Releases und Obtainium ohne Google Play Store Abhaengigkeit.")
        ])
    ]
    
    cur_row = 3
    for sec_title, items in dod_sections:
        ws4.cell(row=cur_row, column=1, value=sec_title).font = section_font
        cur_row += 1
        
        ws4.cell(row=cur_row, column=1, value="Kriterium").font = header_font
        ws4.cell(row=cur_row, column=1).fill = accent_bar_fill
        ws4.cell(row=cur_row, column=1).border = thin_border
        
        ws4.cell(row=cur_row, column=2, value="Verbindliche Vorgabe & Pruefschritt").font = header_font
        ws4.cell(row=cur_row, column=2).fill = accent_bar_fill
        ws4.cell(row=cur_row, column=2).border = thin_border
        ws4.merge_cells(start_row=cur_row, start_column=2, end_row=cur_row, end_column=5)
        cur_row += 1
        
        for k, v in items:
            c1 = ws4.cell(row=cur_row, column=1, value=k)
            c1.font = data_bold
            c1.fill = white_fill
            c1.border = thin_border
            
            c2 = ws4.cell(row=cur_row, column=2, value=v)
            c2.font = data_font
            c2.fill = white_fill
            c2.border = thin_border
            ws4.merge_cells(start_row=cur_row, start_column=2, end_row=cur_row, end_column=5)
            cur_row += 1
            
        cur_row += 1 # Empty spacing row
        
    ws4.column_dimensions['A'].width = 28
    ws4.column_dimensions['B'].width = 30
    ws4.column_dimensions['C'].width = 25
    ws4.column_dimensions['D'].width = 25
    ws4.column_dimensions['E'].width = 25

    # Ensure output dir exists and save
    output_path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(output_path)
    print(f"Excel-Datei erfolgreich erstellt: {output_path}")

def generate_markdown_tickets(base_dir: Path, tickets_md_path: Path):
    issues_dir = base_dir / ".scratch" / "nocturne" / "issues"
    issues_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Per-ticket files under .scratch/nocturne/issues/<NN>-<slug>.md
    for t in TICKETS:
        num = t["id"].replace("TICK-", "")
        slug = t["title"].lower()
        for ch in [" ", "/", "(", ")", "&", ",", ".", "_"]:
            slug = slug.replace(ch, "-")
        while "--" in slug:
            slug = slug.replace("--", "-")
        slug = slug.strip("-")[:40]
        
        file_name = f"{num}-{slug}.md"
        file_path = issues_dir / file_name
        
        ac_lines = "\n".join([f"- [ ] {ac}" for ac in t["acceptance_criteria"]])
        
        content = f"""# {num}: {t['title']}

**What to build:**
{t['deliverable']}

**Blocked by:**
{t['blocked_by']}

**Phase:** {t['phase']}
**Type:** {t['type']} | **Layer:** {t['layer']} | **Points:** {t['points']} | **Priority:** {t['priority']}
**Status:** ready-for-agent

**Acceptance criteria:**
{ac_lines}

**Verification method:**
{t['verification']}
"""
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
            
    print(f"{len(TICKETS)} Ticket-Dateien erfolgreich unter {issues_dir} erstellt.")
    
    # 2. Complete Markdown Catalog in docs/tickets/TICKETS.md
    tickets_md_path.parent.mkdir(parents=True, exist_ok=True)
    with open(tickets_md_path, "w", encoding="utf-8") as f:
        f.write("# Nocturne - Entwicklungs-Backlog & Ticket-Katalog\n\n")
        f.write("Dieses Dokument enthaelt saemtliche 36 Entwicklungs-Tickets fuer Nocturne, aufgeteilt in 6 Phasen.\n")
        f.write("Die formatierte Excel-Tabelle befindet sich unter `docs/tickets/nocturne_tickets.xlsx`.\n\n")
        f.write("---\n\n")
        
        current_phase = ""
        for t in TICKETS:
            if t["phase"] != current_phase:
                current_phase = t["phase"]
                f.write(f"## {current_phase}\n\n")
                
            f.write(f"### {t['id']}: {t['title']}\n\n")
            f.write(f"- **Deliverable:** {t['deliverable']}\n")
            f.write(f"- **Blocked by:** {t['blocked_by']}\n")
            f.write(f"- **Prio / Points:** {t['priority']} | {t['points']} Story Points\n")
            f.write(f"- **Typ / Schicht:** {t['type']} | {t['layer']}\n")
            f.write(f"- **Status:** `{t['status']}`\n")
            f.write("- **Akzeptanzkriterien:**\n")
            for ac in t["acceptance_criteria"]:
                f.write(f"  - [ ] {ac}\n")
            f.write(f"- **Verifikation:** {t['verification']}\n\n")
            
    print(f"Katalog erfolgreich erstellt: {tickets_md_path}")

if __name__ == "__main__":
    root_dir = Path(__file__).resolve().parents[2]
    excel_file = root_dir / "docs" / "tickets" / "nocturne_tickets.xlsx"
    catalog_file = root_dir / "docs" / "tickets" / "TICKETS.md"
    
    build_excel(excel_file)
    generate_markdown_tickets(root_dir, catalog_file)
