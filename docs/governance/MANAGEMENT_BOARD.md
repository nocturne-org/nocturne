# Nocturne Governance: C-Level Management Board

Dieses Dokument definiert die verbindliche Fuehrungs- und Kontrollstruktur fuer Nocturne.
Jeder Entwicklungsschritt, jedes Feature und jeder Release durchlaeuft die Pruefung dieses Gremiums.

---

## 1. Das Management-Board (Rollen & Zustaendigkeiten)

```
                 +-----------------------------------------+
                 |            ROGER (Owner)                |
                 |      Chief Executive Officer (CEO)      |
                 |       Vision, Veto & Freigaben          |
                 +--------------------+--------------------+
                                      |
       +------------------------------+------------------------------+
       |                              |                              |
+------v-------+              +-------v------+              +--------v-----+
| HEAD OF LAW  |              |   HEAD OF    |              |   HEAD OF    |
|   (Legal &   |              |   SECURITY   |              |  PRODUCTION  |
| Compliance)  |              | (App & Data) |              |  (QA & CI)   |
+--------------+              +--------------+              +--------------+
```

---

### Rolle 1: Chief Executive Officer (CEO) - Roger / Antigravity Orchestrator
- **Mandat:** Gesamtstrategische Ausrichtung, Priorisierung der Backlog-Tickets, finales Veto und Freigabe von Releases.
- **Prinzip:** Maximale Nutzerzentrierung (bedtime-fokussiert, blind bedienbar, blendfrei) bei absoluter Reversibilitaet aller Systemeingriffe.
- **Aufgaben:**
  - Entscheidet ueber Zielkonflikte zwischen Komfort und Sicherheit.
  - Erteilt die finale Freigabe fuer GitHub Release Tags (`v1.0.X`).

---

### Rolle 2: Head of Law (Legal & Compliance Manager)
- **Mandat:** Gewaehrleistung von Rechtssicherheit, Urheberrechts-Konformitaet und Schutz des Open-Source-Status.
- **Gesetzliche Leitplanken:**
  1. **Privatkopie-Schranke (§ 53 dUrhG / § 42 öUrhG / EU InfoSoc 2001/29/EG):**
     - Lokales Herunterladen oeffentlich zugaenglicher Streams fuer den rein privaten, nicht-kommerziellen Eigengebrauch ist legal, sofern kein wirksamer technischer Kopierschutz (Widevine/DRM) umgangen wird.
  2. **Dual-Use & Werkzeug-Prinzip:**
     - Nocturne ist wie VLC, NewPipe oder yt-dlp ein medienneutraler Client. Die App enthaelt selbst keine urheberrechtlich geschuetzten Werke.
  3. **Marken- & Plattform-Neutralitaet:**
     - Keine Verwendung geschuetzter YouTube-Wortmarken oder Original-Logos im UI (Bezeichnung als "Web-Stream" oder "Video-Stream").
     - Keine Authentifizierung ueber Google-Nutzerkonten (Schutz der Endnutzer vor Account-Sanktionen).
  4. **Lizenz-Compliance (GNU GPL v3.0):**
     - Wahrung des Copyleft-Prinzips: Saemtlicher Code bleibt frei zugaenglich; keine proprietaren Blobs.
  5. **DSGVO & Datenschutz (Zero-Telemetry):**
     - 100% lokale Speicherung aller Daten (Drift SQLite). Keine Tracking-Pixel, keine Analyse-Server, keine Weitergabe von IP-Adressen.

---

### Rolle 3: Head of Security (Security & App-Hardening Manager)
- **Mandat:** Schutz vor Schadcode, Datenabfluss, Injection-Angriffen und unberechtigtem Systemzugriff.
- **Sicherheits-Leitplanken:**
  1. **Input-Sanitization & Path-Traversal-Schutz:**
     - Jeder vom Nutzer oder Dateisystem uebergebene Pfad wird vor dem Einlesen sanitiert (`PathSanitizer`). Sequenzen wie `../` werden strikt blockiert, um Ausbrueche aus erlaubten Ordnern zu verhindern.
  2. **SQL-Injection-Immunitaet:**
     - Drift SQLite erzwingt ausnahmslos typisierte Prepared Statements mit gebundenen Variablen (`WHERE id = ?`). Rohe SQL-String-Konkatenation ist im gesamten Quellcode untersagt.
  3. **Netzwerk-Sicherheit (TLS 1.3 & LAN-Isolation):**
     - Oeffentliche Streams muessen zwingend verschluesselt ueber HTTPS (TLS 1.2/1.3) laufen.
     - Unverschluesseltes HTTP wird ausschliesslich fuer private lokale RFC-1918-IP-Adressen freigegeben (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`).
  4. **App-Sandbox & Storage Access:**
     - Downloads und Cache-Dateien liegen isoliert im App-internen Sandbox-Verzeichnis (`/data/user/0/com.nocturne.audio/files/`), unzugaenglich fuer fremde Apps ohne Root.
  5. **Air-Gapped Schutz fuer Secrets:**
     - Keine privaten Passwoerter, Nextcloud-App-Tokens oder API-Keys duerfen im Git-Repository versioniert werden (`.gitignore` und `.antigravityignore` pruefen).

---

### Rolle 4: Head of Production (QA, CI/CD & Reliability Manager)
- **Mandat:** Stabilitaet, Testabdeckung, fehlerfreie Builds und akkuspezifische Android-Laufzeitguete.
- **Produktions-Leitplanken:**
  1. **100% gruene Test-Gateways:**
     - Kein Commit und kein Release ohne erfolgreichen Lauf von `flutter test` (240+ Tests) und `flutter analyze --fatal-warnings --no-fatal-infos` (0 Fehler, 0 Warnungen).
  2. **Akku- & Doze-Hygiene (Schlafzimmer-Standard):**
     - `WAKE_LOCK` und `FOREGROUND_SERVICE` werden strikt nur waehrend aktiver Audiowiedergabe gehalten.
     - Sobald die Wiedergabe pausiert oder der Schlaftimer ablaeuft, wird die Audio-Session freigegeben und die CPU sofort in den Tiefschlaf versetzt (0% Standby-Verbrauch).
  3. **Deterministische Build-Pipeline:**
     - GitHub Actions baut vollautomatisch signierte Split-APKs (`arm64-v8a`) und universelle Releases inklusive SHA-256 Pruefsummen (`sha256sums.txt`) fuer Obtainium.
  4. **Strikte Reversibilitaet:**
     - Jeder einzelne Release-Schritt ist ueber Git-Tags und fruehere Commits mit einem einzigen Befehl rollbar:
       `git reset --hard HEAD~1`
