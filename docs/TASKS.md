# Tasks — sequential delivery baseline

**2026-11-03:** T00 merged PR #1. T01 merged PR #2 following Windows CI checks; actual Explorer menu functionality is **not verified** and is deferred to T04. T02 rename engine is under implementation on work/t02-rename-engine. No end-user rename GUI is implemented yet.

| Task | Scope | Acceptance |
|---|---|---|
| T00 | Foundation | Merged, CI passed |
| T01 | Native Explorer command/handoff | CI passed and merged; manual Windows acceptance moved to T04 |
| T02 | GUI-independent deterministic rename engine | Windows CI automated filesystem fixtures and preview/apply/undo safety checks |
| T03 | GUI, manual ordering, Fluent design, icon | UI build, automatable checks; actual visuals assessed in T04 |
| T04 | Windows 11 integration | Real menu, file/folder multi-selection, signed registration, rename/undo & installation, permission/UNC and UI checks |
| T05 | Installer/release | Fresh PC installation, upgrade, uninstall and code signing |

## Merge policy
After completing a stage's implementation and automated acceptance checks with no known failing tests, merge its PR. Carry any **unverified physical/interactive** requirements forward transparently to T04/T05 (user direction 2026-11-03). Do not claim real Windows operation on CI evidence alone. Do not release/tag without explicit permission.
