# Rule: Development Language Directive (English for Codebase)

## 1. Scope & Mandate
- **Chat Interaction:** Communication language with the user in chat can remain flexible (e.g., German or English, depending on user input).
- **Codebase & Development:** ALL development artifacts must strictly be written in **ENGLISH**.
  - All source code (`lib/`, `android/`, `test/`).
  - Code comments and docstrings.
  - Variable, function, class, and method identifiers.
  - In-app UI strings, labels, tooltips, dialogs, and error messages.
  - Git commit messages, branches, and PR bodies.
  - Technical tickets, specs, plans, and architectural documentation (`docs/`, `.scratch/`).

## 2. Prohibition of German in Code
- German comments (e.g. `// Vor dem Eingriff`, `// Umschalter`), German identifiers, or German UI string literals are strictly forbidden in new changes.
- Existing German strings and comments will be systematically refactored to clean English as files are modified.

## 3. Typography Integrity
- Exclusively use standard ASCII hyphen `-` (no En-dash U+2013 or Em-dash U+2014).
