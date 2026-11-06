# Nocturne - Workspace Directives

## Development Language
- **Chat:** Flexible (German/English as preferred by user).
- **Code & Development Artifacts:** **Strictly ENGLISH only**.
  - All source code, identifiers, comments, and docstrings in `lib/`, `test/`, and `android/`.
  - All UI strings, button labels, toasts, and dialogs.
  - All Git commit messages, branches, and PRs.
  - All documentation in `docs/` and ticket files.

## Architecture & Code Quality
- Clean Architecture (Domain, Data, Presentation, Platform).
- State Management: Riverpod 2.5+.
- Persistence: Drift SQLite.
- Background Audio: JustAudio & AudioService with foreground notification.
- UI Design: AMOLED Pure Black `#000000`, Midnight Blue `#3B82F6`, Indigo `#6366F1`, Violet `#8B5CF6`.
- Typography: Exclusively standard ASCII hyphen `-`. No En-dash (U+2013) or Em-dash (U+2014).
