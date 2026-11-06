# Architektur-Review: Nocturne v2.0 Erweiterungs-Anforderungen

Stand: 2026-11-06 - Basis: Commit `f8f396c` (Arbeitsbaum nur mit ungetracktem `.scratch/ui-ux-redesign/`)

Geprüfte Anforderungsblöcke:

1. Sleep-Timer mit Presets 5/10/15/30 Min, freie Minuteneingabe, Aus/Stop, Kapitelende
2. Ordner-Import per Pfad (rekursiv, 6 Formate), Auto-Playlist, Sofort-Wiedergabe
3. YouTube-Suche (Video/Audio + URLs), Favoriten-Herz, Playlist-Plus, Playlist-Picker mit Suche/Scroll/Sortierung "zuletzt hinzugefügt"
4. Audio/Video-Umschaltung (PiP), Stream vs. Offline-Download, minimale Download-Kompression (Opus 64 kbps)

Der Review ist code-gebunden. Jede Aussage verweist auf Datei und Symbol im Repository, nicht auf allgemeine Best Practices.

---

## 0. Kurzbefund

| Anforderung | Ist-Zustand im Code | Reifegrad |
| :--- | :--- | :---: |
| Sleep-Timer Presets | `SleepTimerPreset` hat `m15/m30/m45/m60/untilChapterEnd/custom`, nicht 5/10/15/30 | 40% |
| Sleep-Timer Zustandslogik | Zwei konkurrierende `SleepTimerState`-Klassen, `TimerController` dupliziert `SleepTimerStateMachine` | 50% |
| Ordner-Import | `dart:io`-Scan vorhanden, Formatliste unvollständig, kein Playlist-Erzeugnis | 55% |
| YouTube-Suche | Kein Such-Endpunkt in `InnerTubeResolver`, Client liefert Fixture-JSON | 10% |
| Favoriten/Playlists | Keine Tabelle, kein DAO, kein Modell in `lib/` | 0% |
| Audio/Video-Toggle | `VideoModeController` vorhanden, Positionsübergabe fragil, Fallback-Pfade maskieren Fehler | 60% |
| Offline-Download | Transport schreibt Dummy-Bytes, keine Transkodierung | 15% |
| Minimale Kompression (Opus 64) | Keine Re-Encode-Stufe, Stream-Auswahl priorisiert 128-160 kbps | 0% |

Kernrisiko: Block 3 (Suche, Favoriten, Playlists) ist im Code vollständig ungebaut. Die anderen Blöcke sind zu 40-60% vorhanden, aber mit strukturellen Schulden, die jeder Ausbau verschärft.

---

## 1. Datenschicht und Datenmodell

### 1.1 Befund

- `lib/data/datasources/database/app_database.dart:12` ist eine handgeschriebene Klasse, kein `@DriftDatabase`-Typ mit generiertem `part 'app_database.g.dart'`. Die `*Table`-Objekte in Zeilen 37-41 werden nur gehalten, nie abgefragt.
- `AppDatabase.schemaVersion => 1` (Zeile 29). Es gibt keine `MigrationStrategy`.
- `AppDatabase.transaction` (Zeilen 46-61) setzt nur das Flag `_inTransaction` und ruft `action()` auf. Der `catch`-Block (Zeile 56-57) macht `rethrow` ohne jede Rückabwicklung. Kommentar Zeile 45 ("Bei Fehlern wird ein Rollback durchgefuehrt") ist faktisch falsch.
- `MediaDao` (`lib/data/datasources/database/daos/media_dao.dart:212-216`) hält fünf `Map<String, ...>`-Speicher im Heap. Daten überleben keinen Prozess-Neustart. Für "zuletzt hinzugefügt"-Sortierung und Offline-Favoriten ist das ein Ausschlusskriterium.
- `MediaItemsTable` (`lib/data/datasources/database/tables/media_items_table.dart`) hat `sourceType` und `sourceUri`, aber kein Feld für Ordnername, Import-Wurzelpfad, Download-Status oder Kompressions-Bitrate.
- `docs/architecture/ARCHITECTURE.md:62` behauptet eine Tabelle `playlists`. Sie existiert nicht. Grep über `lib/` findet nur `Icons.playlist_play_rounded` und einen Doc-Kommentar in `media_dao.dart:492` ("PLAYBACK QUEUE"), keine Playlist-Entität.
- `MediaItem` (`lib/domain/models/media_item.dart`) kennt `type`, `album`, `metadata: Map<String, dynamic>` (Zeile 60). `album` ist ein String ohne Fremdschlüssel. Eine Sortierung oder Gruppierung nach Playlist ist damit nur über String-Vergleich möglich.

### 1.2 Empfehlung

1. **Drift echt aktivieren.** `@DriftDatabase(tables: [...])` plus `drift_dev` und `build_runner`. `schemaVersion: 2`. Migration `v1 -> v2` neu schreiben, da v1 nie produktiv war (kein Release mit persistenter DB), also `onCreate` als Baseline zulassen und `schemaVersion` auf 1 belassen.
2. **Neue Tabellen für Block 3:**
   - `playlists`: `id`, `name`, `kind` (`user` | `folderImport` | `youtubeAuto`), `sourcePath` (nullable, nur bei Ordner-Import), `createdAt`, `sortOrder`
   - `playlist_items`: `playlistId`, `mediaItemId`, `addedAt` (indexiert), `sortOrder` - `addedAt` ist direkt die Sortierung "zuletzt hinzugefügt"
   - `favorites`: `mediaItemId` als Primary Key, `addedAt`
   - Index: `CREATE INDEX idx_playlist_items_added ON playlist_items(playlist_id, added_at DESC)`
3. **`MediaItemsTable` erweitern:** `downloadStatus` (`none|queued|downloading|completed|failed`), `downloadProfile` (`opus64|original|video`), `sourceFolder` (nullable, Wurzelpfad des Imports), `externalId` (YouTube-Video-ID, nullable, unique).
4. **Echte Transaktionen.** Playlist-Erzeugnis beim Ordner-Import und Favoriten-Umschaltung sind Multi-Row-Operationen. Ohne atomare Transaktion bleibt bei einem Abbruch eine halbe Playlist liegen. Der aktuelle `transaction()` erlaubt genau das.
5. **`TransactionRunner` beibehalten?** Nein. `MediaDao` soll den generierten Drift-DAO erweitern oder kapseln, statt `Future<T> Function<T>(Future<T> Function())` durchzureichen (`media_dao.dart:198-210`). Die Injektion kaschiert den fehlenden Rollback.

---

## 2. Block 1: Sleep-Timer

### 2.1 Befund

- **Preset-Mismatch.** `SleepTimerPreset` (`lib/domain/models/sleep_timer_state.dart:20-26`) enthält `m15, m30, m45, m60, untilChapterEnd, custom`. Die Anforderung lautet 5/10/15/30 Min plus freie Eingabe plus Kapitelende. `m45` und `m60` sind überflüssig, `m5` und `m10` fehlen. `SleepTimerState.initial` (Zeile 94-100) setzt `preset: SleepTimerPreset.m30`.
- **Zwei Zustandsklassen.** `lib/domain/models/sleep_timer_state.dart:65` (`SleepTimerState` mit `SleepTimerStatus`-Enum, `volumeFactor`, `extendInterval`) und `lib/presentation/state/sleep_timer_state.dart:2` (`SleepTimerState` mit `isActive`, `isFadingOut`, `isGracePeriod`, `currentVolume`, `gracePeriodRemaining`). Beide heißen gleich und modellieren denselben Zustand unterschiedlich. Der Domain-Typ hat 5 Status-Werte, der Presentation-Typ 4 Bool-Flags, die sich widersprechen können (`isFadingOut == true` und `isGracePeriod == true` gleichzeitig konstruierbar).
- **Doppelte Logik.** `TimerController` (`lib/presentation/providers/timer_providers.dart`) implementiert Countdown, Fade `(t/60)^2` (Zeile 70-71) und 120-Sekunden-Grace selbst. Parallel existiert `SleepTimerStateMachine` unter `lib/domain/usecases/`. Der Presentation-Controller importiert die Domain-Maschine nicht.
- **Kein Kapitelende, kein Stop-ohne-Reset-Signal.** `SleepTimerPreset.untilChapterEnd` hat `fixedDuration == null` (Zeile 39-41). Es gibt in `TimerController` keinen Pfad, der das Ende des aktuellen Kapitels als Trigger verwendet. `cancelTimer()` (Zeile 102-104) setzt hart auf `SleepTimerState.initial`. Der Unterschied zwischen "Timer aus, Wiedergabe läuft weiter" und "Wiedergabe stoppen" ist im Zustand nicht abbildbar.
- **Keine Persistenz.** Fade-Phase, Grace-Rest und Gesamtdauer leben nur im Riverpod-Notifier. Ein Prozess-Tod (Android Doze, Kill im Hintergrund) verliert den Timer lautlos. `SleepPresetEntry` (`media_dao.dart:85`) hat bereits `autoFadeOutSeconds`, `shakeGracePeriodSeconds`, `autoRewindSeconds`, aber der Controller liest keine Presets aus dem DAO.
- **`tick` kennt Drift nicht.** `tick(Duration elapsed)` subtrahiert die übergebene Dauer. Nach langer Doze-Pause geht das nicht schief, weil `elapsed` korrekt ist, aber der Fade startet erst, wenn ein Tick nach dem Erreichen der 60-Sekunden-Grenze eintritt. Ohne `Wall-Clock`-Anker (`startedAt`-Zeitstempel) kann nach einem Neustart nicht rekonstruiert werden, was übrig bleibt.

### 2.2 Empfehlung

1. **Preset-Enum auf Anforderung umstellen:** `m5, m10, m15, m30, custom, untilChapterEnd`. `fixedDuration` liefert `Duration(minutes: 5/10/15/30)` und `null` für die beiden dynamischen. Label-Getter bleibt.
2. **Eine Zustandsklasse.** Domain-`SleepTimerState` behalten (Status-Enum ist strikter als Bool-Flags), Presentation-Klasse löschen. `TimerController` wird reiner Adapter: er hält `SleepTimerStateMachine` und ruft `machine.applyTick(...)`.
3. **Zwei Achsen im Zustand trennen:** `SleepTimerMode { off, countdown, untilChapterEnd }` und `SleepTimerPhase { counting, fadingOut, gracePeriod, stopped }`. "Aus" ist damit ein Modus, kein initialer Zustand mit `remaining == 0`.
4. **Kapitelende-Trigger:** `untilChapterEnd` wird nicht getickt, sondern hört auf `positionStream` des Players und vergleicht mit `mediaItem.chapters`. Erreicht die Position `chapter.end`, geht es in `fadingOut` über. Die Fade-Dauer kommt aus `SleepPresetEntry.autoFadeOutSeconds`.
5. **Persistenz:** `startedAt` (UTC, ISO-8601) und `totalDuration` in `SleepPresetsTable` bzw. SharedPreferences schreiben. Bei Kaltstart `remaining = total - (now - startedAt)`, dann neu einsteigen. Grace-Phase genauso.
6. **"Stop" vs. "Aus":** Eigener Callback `onHardStop` im Use Case, der `_player.stop()` aufruft. Der reine Timer-Aus-Pfad bleibt `cancelTimer()`. Anforderung "aus/stop" erfordert beide.

---

## 3. Block 2: Ordner-Import per Pfad

### 3.1 Befund

- **Formate unvollständig.** `AudioFormat` (`lib/data/scanner/audio_format.dart:2-7`) enthält `mp3, m4b, m4a, flac, opus`. Es fehlen `aac`, `ogg`, `wav`, die die Anforderung explizit nennt. Anforderung fordert sechs Formate, Code deckt vier davon ab.
- **Stiller Fehlerpfad.** `LibraryScanner.scanDirectory` (`lib/data/scanner/library_scanner.dart:56-58`) gibt `[]` zurück, wenn `dir.exists()` falsch ist. Der Aufrufer kann "Pfad ungültig" nicht von "Ordner leer" unterscheiden. `_traverseDirectoryInIsolate` (Zeile 13) hat denselben Fehlerpfad.
- **Pro-Datei-Fehler werden verschluckt.** `catch (_)` in Zeile 35-37 ignoriert gesperrte oder nicht lesbare Dateien. Nutzer sieht eine kürzere Liste ohne Hinweis.
- **Symlinks nicht verfolgt, aber auch nicht gemeldet.** `followLinks: false` (Zeile 16). Korrekt für Sicherheit, aber der Nutzer importiert unter Umständen ein gespiegeltes Verzeichnis und verliert jeden Eintrag lautlos.
- **Kein Playlist-Erzeugnis.** Der Scanner liefert `List<ScannedAudioFile>`. Ich finde in `lib/data/scanner/` und in `media_dao.dart` keinen Codepfad, der daraus eine Playlist mit dem Ordnernamen erzeugt. Die Anforderung "Playlist automatisch mit Ordnernamen erstellen" ist ungebaut.
- **Keine Wiedergabe-Kopplung.** `scanDirectory` gibt ein Objekt zurück. Es gibt keinen Use Case "Scan -> Persist -> Wiedergabe starten", der das erste File an `AudioPlayerRepository` übergibt.
- **Nur Pfad, kein SAF.** `dart:io Directory` funktioniert auf Android nur mit dem Pfad, den die App lesen darf. Ohne `MANAGE_EXTERNAL_STORAGE` (Play-Store-untauglich) oder SAF-Tree-URI ist der Ordner-Pfad-Import auf Android 11+ für freie Pfade nicht möglich. Der Parameter `rootPath` ist ein String, `sourceType` in `MediaItemsTable` kennt bereits `safTree`. Der Scanner nutzt diese Quelle nicht.

### 3.2 Empfehlung

1. **`AudioFormat` erweitern:** `aac('aac', 'audio/aac')`, `ogg('ogg', 'audio/ogg')`, `wav('wav', 'audio/wav')`. `fromPath` bleibt. Zusätzlich `isSupported` prüft statt zu werfen.
2. **Fehlertyp statt leerer Liste:** Rückgabe `ScanResult { files, rootMissing, unreadableFiles, skippedLinks }`. `scanDirectory` wirft `DirectoryNotFoundException` für ungültigen Pfad. UI unterscheidet dann "Pfad existiert nicht", "kein Audio gefunden", "N Dateien übersprungen".
3. **Playlist-Erzeugnis als Use Case:** `ImportFolderAsPlaylist(folderPath)`. Ablauf: (a) Pfad validieren, (b) `scanIncremental` mit den vorhandenen `sourceFolder`-Einträgen, (c) Transaktion: `playlists.insert(kind: folderImport, sourcePath)`, `playlist_items.insertAll(items mit addedAt = Datei-mtime oder jetzt)`, (d) `media_items` upsert mit `sourceFolder`. Playlist-Name = `p.basename(folderPath)`, bei Kollision Suffix ` (2)`.
4. **Sofort-Wiedergabe:** Nach Schritt (c) den Use Case `PlayPlaylistFromStart(playlistId)` aufrufen. Das ist Server-frei testbar, wenn der Player über die bestehende `AudioPlayerRepository`-Schnittstelle injiziert wird.
5. **SAF als zweiter Pfad:** `sourceType: safTree` in `MediaItemsTable` ist bereits vorgesehen. Ein `SafTreeScanner` mit `persistable permission` als String-URI speichern. Der reine Pfad-Scan bleibt als Desktop/Debug-Weg.
6. **Determinismus:** Sortierung der `ScannedAudioFile` vor dem Insert nach `(relativePath, fileName)`. `listSync` garantiert keine Reihenfolge. Ohne explizite Sortierung ist "Playlist in Ordnerreihenfolge" nicht reproduzierbar.

---

## 4. Block 3: YouTube-Suche, Favoriten, Playlists

### 4.1 Befund

- **Kein Such-Endpunkt.** `InnerTubeResolver` (`lib/data/resolvers/innertube_resolver.dart`) hat keinen Treffer für `search`. Grep über `lib/` bestätigt: es existiert nur lokale Bibliothekssuche, keine YouTube-Suche.
- **Client liefert Fixtures.** `DefaultInnerTubeClient.fetchPlayerResponse` gibt hartkodiertes JSON zurück mit einem 160-kbps-`mp4a`- und einem 128-kbps-Opus-Format. Ein echter Netzwerkpfad fehlt.
- **`decipherNSig` ist ein Platzhalter.** `innertube_resolver.dart` implementiert die NSig-Dechiffrierung als paarweisen Zeichentausch plus Umkehrung. YouTube ändert das JS alle paar Wochen. Das Verfahren ist funktional nie korrekt, aber so gebaut, dass Tests es nicht merken.
- **Keine Favoriten/Playlist-Entitäten.** `MediaItem` hat kein `isFavorite`. `MediaDao` hat keine `addToPlaylist`, `removeFromPlaylist`, `watchFavorites`. Nur `PlaybackQueueEntry` (`media_dao.dart:162`) als flache Warteschlange mit `sortOrder` und `isCurrent`.
- **Playlist-Picker ungebaut.** Für Suche im Picker, Scroll und Sortierung "zuletzt hinzugefügt" fehlt jede Query-Schicht. Ohne DB-Index (`added_at DESC`) würde die Sortierung bei wachsender Playlist-Größe in-memory laufen (aktuell `media_dao.dart:517-518` sortiert vollständig im Heap pro Abruf).
- **Kein URL-Eingabepfad.** Der Resolver nimmt nach heutigem Stand keine Nutzer-URL entgegen (kein `resolveUrl`-Symbol). Anforderung "URLs einfügen" ist ungebaut.

### 4.2 Empfehlung

1. **`YouTubeSearchClient` neu:** `searchVideos(query, {videoFilters, audioOnly})`, `searchByUrl(url)` mit Parsing von `youtube.com/watch?v=`, `youtu.be/`, `music.youtube.com`. Rückgabe `List<YouTubeSearchResult { videoId, title, channel, duration, thumbnail, isLive }>`.
2. **ISOLIERUNG:** Netzwerk-Client hinter Interface, echte Implementierung mit `http` und `package:youtube_explode_dart` oder eigenen InnerTube-Calls, Tests mit `MockClient`. Der bestehende Fixture-Pfad bleibt Test-Double, nicht Default.
3. **NSig echt machen oder entfernen.** Ein `decipherNSig`, der immer Char-Swap ist, ist ein Bug-Generator. Entweder JS-Interpreter (`flutter_js`) oder das Feld ignorieren und nur Formate nutzen, die ohne n-sig abrufbar sind. Platzhalter muss als `UnsupportedError('n-sig nicht implementiert')` enden, damit Tests keine falsche Sicherheit liefern.
4. **Favoriten:** Tabelle `favorites` (siehe 1.2), Domain-Methode `toggleFavorite(mediaItemId)`, Heart-State in `MediaItem` als `bool isFavorite` aus Join, nicht als persistiertes Feld doppelt. Ein einziger Ort für Wahrheit.
5. **Playlist-Picker:** Provider `watchPlaylistsForPicker(query)` mit `WHERE name LIKE ? LIMIT 50`. Sortierung im Picker: `createdAt DESC` (zuletzt hinzugefügt). Für Scroll-Stabilität `ListView.builder` mit `itemExtent`, nicht `shrinkWrap: true`. Das ist der Punkt, an dem die Sortierung bei 200+ Playlists sonst ruckelt.
6. **Sortierung "zuletzt hinzugefügt" in Playlist:** `playlist_items.addedAt` ist der Anker. Default-Sortierung `addedAt DESC`. Zweiter Sortierschlüssel `mediaItemId` für Determinismus bei gleichen Zeitstempeln.
7. **Plus-Button-Ziel:** `addToPlaylist(playlistId, mediaItemId)` muss `INSERT OR IGNORE` sein (Unique auf `(playlistId, mediaItemId)`), sonst entstehen Dubletten bei schnellem Doppeltipp.

---

## 5. Block 4: Audio/Video-Umschaltung, Streaming, Download

### 5.1 Befund

- **Positionsübergabe einseitig.** `VideoModeController.switchToVideo` (`lib/presentation/controllers/video_mode_controller.dart:128-149`) nimmt `state.currentPosition` zum Zeitpunkt des Aufrufs. Das ist richtig, weil im Audio-Modus der `positionStream` die `state.currentPosition` speist. `switchToAudioOnly` (Zeile 152-176) startet danach `_player.setSource(...)` mit derselben Position. Aber der Videodecoder wurde schon pausiert und `release()`d, bevor `audioUrl` geprüft wird. Ist `audioUrl == null`, bleibt der Zustand im Video-Modus (`isAudioOnly` false) mit freigegebenem Decoder stehen, und `isPlaying` wird trotzdem auf `true` gesetzt (Zeile 174).
- **Fehler werden verschluckt.** `state`-Getter und `state`-Setter (Zeilen 41-56) fangen jede Exception und fallen auf `_manualState` zurück. In Unit-Tests ohne Container funktioniert das, in Produktion maskiert es echte Zustandsfehler: das UI liest dann einen veralteten Wert, ohne dass es auffällt.
- **Bildschirm-Aus schaltet zwangsweise auf Audio.** Zeile 83-89 ruft bei `!screenOn && state.isVideo` sofort `switchToAudioOnly()` auf. Bei aktivem PiP will der Nutzer im Video bleiben. PiP-Status ist erst im Callback Zeile 92-94 bekannt, aber die Reihenfolge der Streams entscheidet, wer gewinnt. Ohne Guard `if (state.isPipActive) return;` ist das ein Wettlauf.
- **`DefaultDownloadHttpTransport` schreibt Dummy-Bytes.** `lib/data/download/download_manager.dart:32` schreibt `List.filled(10000, 0xAA)` und meldet `onProgress(10000, 10000)`. Es gibt keinen `HttpClient`, keinen Range-Header, kein `acceptRanges`. Jeder Download ist eine 10-KB-Datei, die in `TagInjector` als "erfolgreich" gilt.
- **Extension-Rate.** Zeile 78: `streamUrl.contains('.opus') ? 'opus' : 'm4a'`. YouTube-Stream-URLs enthalten keine Extension. Jeder Download landet als `.m4a`, auch wenn es Opus ist.
- **Keine Transkodierung.** Anforderung "Opus 64 kbps, kleinste Größe" verlangt Re-Encode. `DownloadManager._processTask` (Zeile 138-215) hat keine Transkodier-Stufe. `Transfer`-Pipeline ist: Transport -> `TagInjector` -> `rename`. Kein `ffmpeg`, kein `ffmpeg_kit_flutter`, keine Bitraten-Prüfung.
- **`TagInjector` ist speicherlastig.** `injectTagsIntoFile` (Zeile 94-117) liest die ganze Datei mit `readAsBytes`, kopiert sie in einen zweiten `Uint8List` und schreibt sie. Für einen 300-MB-Download sind das 600 MB Heap plus Original. Auf schwachen Geräten Out-of-Memory-Risiko.
- **Stream-Auswahl widerspricht Anforderung.** `AudioOnlyStreamSelector._scoreCandidate` (`lib/data/resolvers/audio_stream_selector.dart:139-147`) belohnt `128-160 kbps` mit `+100`, `>160` mit `+60`, `<128` mit rohem Wert. Eine 64-kbps-Opus-Variante bekommt nur `+50 (Opus) + 64 = 114`, eine 128-kbps-Opus-Variante `+50 + 100 = 150`. Das System wählt aktiv die größere Datei. Anforderung "kleinste Größe" wird vom eigenen Selector konterkariert.
- **`AudioQualityPreference.low = 64`** existiert, aber der Selector nimmt sie nicht als Parameter. `selectBestAudioStream` hat nur `preferOpus`, kein `targetKbps` oder `maxKbps`.
- **PiP-Plattformpfad gibt `false`.** `PipController.enterPip` liefert bei jeder `PlatformException` `false`. `screenStateStream` liefert `Stream.empty()` bei Fehler. Kein Grund, kein Log. Der Nutzer sieht "PiP geht nicht" ohne Diagnose.
- **`enqueueDownload` schätzt 25 MB pauschal** (Zeile 66). Eine 3-Stunden-Audiostunde bei Opus 64 kbps sind ca. 86 MB. Die Größenprüfung `checkStorageSpace` ist damit systematisch zu optimistisch.

### 5.2 Empfehlung

1. **Transport echt implementieren:** `HttpClient` mit `Range`-Header für Resume, `totalBytes` aus `Content-Length`. `partPath` bleibt. `pauseDownload` schreibt den Offset in `DownloadTask.downloadedBytes`, `resumeDownload` setzt `Range: bytes=N-`. Ohne echtes Range ist Pause/Fortsetzen nicht implementierbar.
2. **Zwei-Format-Pipeline trennen:**
   - `downloadProfile.opustream`: YouTube-Opus-Stream direkt laden, kein Re-Encode. Größe sofort minimal. `AudioFormat.fromPath` bleibt unberührt.
   - `downloadProfile.opus64`: Ausgangsdatei (m4a/mp4) mit `ffmpeg -vn -c:a libopus -b:a 64k -application audio -vbr off` umkodieren, dann Original löschen. Ergebnis kleiner als Quellstream bei Sprache.
   Die Entscheidung hängt am Selector-Ergebnis, nicht am URL-Substring.
3. **`AudioOnlyStreamSelector` umbauen:** Parameter `{int? targetKbps, int? maxKbps, bool preferOpus}`. Score = `-(bitrate - target).abs()` plus Opus-Bonus. `AudioQualityPreference.low (64)` mappt auf `targetKbps: 64`. Die Konstante `+100 für 128-160` fällt weg.
4. **Extension aus `mimeType`:** `audio/webm` -> `.opus` (oder `.webm`), `audio/mp4` -> `.m4a`. `AudioStreamCandidate.container` liefert das bereits.
5. **`TagInjector` streamt:** Header schreiben, dann `targetFile.openRead(skipOffset, length)` in eine Zieldatei kopieren mit `IOSink.addStream`. Speicher bleibt konstant. Alternativ auf ID3v1 verzichten und Metadaten nur in `media_items` halten, keine Datei-Rewrite.
6. **`switchToAudioOnly` härten:** Erst prüfen `audioUrl != null`. Wenn nicht, Abbruch mit `UnsupportedError`, kein Zustandswechsel. `isPlaying` aus dem tatsächlichen Player-Status ableiten, nicht hart auf `true` setzen.
7. **`state`-Getter/Setter:** `_manualState` entfernen. `VideoModeController` ist ein Riverpod-Notifier, Tests liefern eine echte `ProviderContainer`. Overrides für Player, Decoder und PiP existieren schon in Konstruktorzeilen 14-24, sie reichen für Isolation.
8. **Bildschirm-Aus/ PiP:** Guard `if (state.isPipActive) return;` vor Auto-Switch. Zusätzlich `AndroidLifecycle`-Event auswerten, nicht nur den Screen-Stream.
9. **PiP-Fehler melden:** `PipController.enterPip` soll `PipResult { success, reason }` liefern oder `Result<bool, PipError>`. Silent `false` ist nicht diagnostizierbar.
10. **Speicher-Schätzung:** `enqueueDownload` soll `estimatedSizeBytes` aus `AudioStreamCandidate.contentLengthBytes` beziehen, wenn vorhanden. Fallback `targetKbps * durationSeconds / 8`. Die Konstante 25 MB entfernen.

---

## 6. Randfälle und Querschnitts-Themen

| Randfall | Verhalten heute | Was fehlt |
| :--- | :--- | :--- |
| Ungültiger Ordnerpfad | `scanDirectory` -> `[]` (`library_scanner.dart:56-58`) | Fehlerobjekt, UI-Meldung |
| Leerer Ordner | `[]`, nicht unterscheidbar | Trenninformation im `ScanResult` |
| Gesperrte Datei | `catch (_)` (`library_scanner.dart:35`) verschluckt | Zählung, Anzeige, Retry |
| Offline-Wiedergabe | Kein Netzzustand im Code gefunden (`connectivity` nicht in `pubspec.yaml`-Nutzung sichtbar) | Pre-Flight-Check, `OfflineOnly`-Schalter, Queue-Pause statt `.failed` |
| Download-Abbruch bei App-Tod | `_queue` ist `Map` im Speicher (`download_manager.dart:52`), `DownloadTask`-Zustand nicht persistiert | `downloads`-Tabelle mit `partPath`, `offset`, Retry |
| Kapitelende-Timer bei Datei ohne Kapitel | `chapters` ist `const []` (`media_item.dart:72`) | Fallback auf Dateiende, im Zustand markieren |
| Doppelt importierter Ordner | `insertMediaItem` wirft `StateError` bei existierender ID (`media_dao.dart:288-290`) | `upsertMediaItem` (Zeile 305) verwenden, Playlist dedupen |
| Playlist doppelt hinzugefügt | Kein Unique-Constraint | `Unique(playlistId, mediaItemId)` |

---

## 7. Umbaureihenfolge (empfohlen)

1. Datenschicht echt machen: Drift-Codegen, echte Transaktion, `schemaVersion`, neue Tabellen für Playlists/Favoriten/Downloads. Alles andere hängt daran.
2. `MediaItem` und `MediaItemsTable` um `favorites`, `downloadStatus`, `externalId`, `sourceFolder` erweitern.
3. Sleep-Timer konsolidieren: Domain-Zustand als einzige Wahrheit, Preset-Enum auf 5/10/15/30, Persistenz über `startedAt`, Kapitelende-Trigger.
4. `AudioFormat` um aac/ogg/wav erweitern, `ScanResult`-Fehlertyp, `ImportFolderAsPlaylist`-Use Case.
5. YouTube: `YouTubeSearchClient` und URL-Parser, NSig-Platzhalter entweder echt oder hart fehlschlagend.
6. Favoriten- und Playlist-Provider, Picker-Suche und Sortierung.
7. Download: echter HTTP-Transport mit Range, `AudioOnlyStreamSelector` mit Target-Bitrate, Opus-64-Re-Encode, `TagInjector`-Streaming.
8. `VideoModeController`-Härtung: Fallback entfernen, `audioUrl`-Guard, PiP-Ausnahme, Fehler-Reporting.

---

## 8. Zusammenfassung in Zahlen

- Anforderungs-Check: 4 Blöcke, 21 Teilpunkte
- Vollständig umgesetzt: 3 (Sleep-Timer Fade-Logik, rekursiver Scan, Video-Decoder-Freigabe)
- Teilweise umgesetzt: 9
- Nicht vorhanden: 9 (u. a. Suche, Favoriten, Playlists, Playlist-Erzeugnis beim Import, aac/ogg/wav, Stop-vs-Aus, Opus-64, Kapitelende-Timer, URL-Eingabe)
- Belegte Struktur-Schulden: 6 (Pseudo-Drift, Pseudo-Transaktion, doppelte Zustandsklasse, Fixture-Client, Dummy-Transport, Fade-Score-Gegensatz)

Der wichtigste Einzelschritt ist Punkt 1 dieses Fazits: ohne echte persistente Datenschicht bleibt jeder Ausbau ein Prototyp.
