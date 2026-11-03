# Tasks — sequential delivery baseline

**2026-11-03:** T00 merged (PR #1), CI passed Windows build and 2 tests. T01 implemented on work/t01-modern-explorer-command; Windows x64 native/identity-package CI and actual Explorer testing are pending. T02–T05 not started.

| Task | Purpose | Acceptance evidence |
|---|---|---|
| T00 | Foundation, MIT, docs, WPF/Core/tests, Windows CI | merged PR #1, CI success |
| T01 | Native first-level Explorer command and path handoff | Windows build/packaging + signed dev registration, real first-level menu and selection/clean removal |
| T02 | Deterministic rename engine | filesystem fixture tests, planner/apply/undo |
| T03 | Fluent UI, sorting, ordering, GUI rules, icon | UI and accessibility tests |
| T04 | Integration verification | actual Windows 11 acceptance suite |
| T05 | Installer and distribution | fresh install/upgrade/uninstall, signing |

## Task gate
- Work one task at a time, record evidence and blockers.
- User authorized merge without an additional request **only when all task exit criteria pass with no unresolved blocker** (2026-11-03).
- If Explorer first-level verification or signed registration is unverified, T01 PR remains open.
- Do not release or tag without explicit authorization.
