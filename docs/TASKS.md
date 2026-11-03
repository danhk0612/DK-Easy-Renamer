# Tasks — sequential delivery baseline

**2026-11-03:** T00 merged PR #1. T01 merged PR #2 with CLI/CI gate, physical Explorer validation deferred to T04. T02 merged PR #3 after 19/19 Windows CI tests passed (no warnings/errors), physical workload checks deferred to T04. **T03** (Fluent GUI) was implemented in PR #4; [Windows CI #19](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41592355535) passed with 19/19 tests and no compile/link warnings. Awaiting merge. No actual visual/user interaction verification has been performed; T04 owns it.

| Task | Scope | Acceptance |
|---|---|---|
| T00 | Foundation | Merged, CI pass |
| T01 | Modern Explorer command and handoff | Merged, CI pass; real desktop checks in T04 |
| T02 | Deterministic rules/preview/apply/undo and ordering | Merged, CI 19/19 pass; realistic files in T04 |
| T03 | WPF-UI GUI, rule editors, manual ordering, preview/apply/undo, icon & themes | CI #19 green, 19/19 tests; PR #4 awaiting merge; physical interactions deferred |
| T04 | Real Windows 11 integration/UX | Explorer menu, file/folder/UNC paths, DPI, install/uninstall, all user-flow tests |
| T05 | Installer and final delivery | Fresh PC install/upgrade/uninstall, signing and publishing acceptance |

## Gate
Merge after automated gates pass without known code defects; explicitly carry physical/manual verification to T04/T05 (user instructions 2026-11-03). No Release/tag until final verification and explicit request.
