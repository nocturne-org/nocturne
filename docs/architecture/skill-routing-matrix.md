# Skill- & Offload-Routing-Matrix (Nocturne)

Dieses Dokument definiert die verbindliche Routing- und Delegationsmatrix fuer alle Manager und Worker im Nocturne-Workspace gemaess den Skills `/subagent-manager` und `/offload-worker`.

---

## 1. Task-zu-Skill-Zuordnung (Worker-Leitfaden)

Vor jeder Code-Modifikation gleicht der Worker die zugewiesene Aufgabe mit dieser Tabelle ab:

| Aufgabentyp & Kriterium | Empfohlener Skill / Workflow | Primaeres Werkzeug / Modell |
| --- | --- | --- |
| **Bulk-Code (> 50 Zeilen)** | `/offload-worker` (Modus: bulk) | `groq/llama-3.3-70b-versatile` ($0,00) via OpenCode |
| **Frontend & UI-Widgets** | `/modern-web-guidance` / Flutter Best Practices | AMOLED Pure Black, min. 48dp Touch-Targets |
| **Neue Logik & Algorithmen** | `/tdd` (Red-Green-Refactor) | Test-First, isolierte Unit-Tests |
| **Schwierige Fehler & Regressions** | `/diagnosing-bugs` | Root-Cause-Hypothese vor Code-Edit |
| **Doku- & API-Recherche** | `invoke_subagent` (TypeName: 'research') | Read-Only Sandbox, offizielle Quellen |
| **Deep Review & Edge-Cases** | `/loop-corrector` / `/offload review` | 4-Stufen-Korrekturschleife vor CompleteTask |
| **Texte, Doku & Markdown** | `/anti-slop` | Praegnante Prosa, striktes ASCII-Minus (`-`) |

---

## 2. Die 5-Stufen-Routing-Matrix (Kosten- & Token-Oekonomie)

Aufgaben werden strikt von Stufe 0 bis Stufe 4 eskaliert:

| Stufe | Zielsystem & Modell | Schwellenwerte (LOC / Dateien) | Kosten / 1M Tokens | Einsatzgebiet |
| --- | --- | --- | --- | --- |
| **Stufe 0** | **OpenCode CLI (Free)**<br>Groq (Llama 3.3 70B), Beam Free 1M, NIM | 1 Datei<br>< 100 LOC (Normal) / < 30 LOC (Economy mid) | $0,00 | Isolierte Funktionen, Tests, Regex, Boilerplate, Parsing |
| **Stufe 1** | **Antigravity IDE (Primaer)**<br>Gemini 3.8 Flash | 1 bis 4 Dateien<br>100 bis 450 LOC | $0,00 | Lokale Diffs, Git-Operationen, Architektur-Orchestrierung |
| **Stufe 2** | **Google Web UI (Architekt)**<br>Gemini 4 Argon (CDP / Clipboard) | Ab 5 Dateien<br>> 500 LOC | $0,00 | Multi-File-Architektur, Modul-Refactoring, 1M Output-Pass |
| **Stufe 3** | **Lokales Ollama (Air-Gapped)**<br>Qwen-Coder 7B (RTX 4060) | 1 bis 2 Dateien<br>< 250 LOC | $0,00 | Vertrauliche Daten, `.env`, Offline-Entwicklung |
| **Stufe 4** | **OpenCode CLI (Paid Fallback)**<br>DeepSeek-V4.1-Flash API | 1 bis 5 Dateien<br>< 400 LOC | $0,15 / $0,60 | Autonome Read-Edit-Bash-Schleifen (max. 4 Turns, $2 Deckel) |

---

## 3. Ausfuehrungs-Syntax (Windows Non-Interactive)

Um ein Blockieren der Standard-Eingabe (stdin) zu verhindern, wird die Ausfuehrung ueber `cmd.exe` mit umgeleitetem `NUL` gekoppelt:

```cmd
cmd.exe /c "opencode run --auto -m groq/llama-3.3-70b-versatile \"<Anweisung>. Verwende strikt Standard-ASCII-Minus (-).\" < NUL 2>&1"
```

---

## 4. Vier-Stufen-Review-Schleife (Qualitaets-Gate)

Vor finalen Releases oder umfangreichen Diffs:

1. **Stufe 1 (Groq Llama 3.3 70B - $0,00):** Syntax, Linter, Imports, Typen.
2. **Stufe 2 (Beam Free 1M - $0,00):** Edge-Cases, Nullpointer, Off-by-one, Timeouts.
3. **Stufe 3 (DeepSeek Non-Pro API - ~$0,001):** Memory-Leaks, Time-Complexity, Clean Architecture.
4. **Stufe 4 (Gemini 4 Argon via CDP - $0,00):** Gesamtarchitektur und Release-Freigabe.

---

## 5. Globale Regeln fuer alle Worker

- **Reversibilitaet:** Vor substanziellen Eingriffen Git-Checkpoint sichern.
- **Typografie:** Ausnahmslos Standard-ASCII-Minus (`-`). En-Dash (U+2013) und Em-Dash (U+2014) sind strengstens verboten.
- **Anti-Slop:** Sachliche, substanzielle Ausgaben ohne Fuellfloskeln.
