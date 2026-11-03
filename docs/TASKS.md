# Tasks — sequential delivery baseline

**2026-11-03:** T00–T03 are merged on main. T01 first-level Explorer registration and T03 GUI interaction passed builds but not physical desktop tests. T02 engine passed 19/19 disposable fixture tests. By user request, **T05 installer code is built before T04 manual integration testing**.

| Task | Scope | Acceptance |
|---|---|---|
| T00 | Foundation | Merged, CI pass |
| T01 | Native Explorer command + handoff | Merged, CI pass; first-level menu unverified until T04 |
| T02 | Core rules/preview/apply/undo | Merged, 19/19 Windows filesystem fixture tests |
| T03 | Fluent WPF GUI, icon, ordering | Merged, Windows build; desktop interaction unverified until T04 |
| T05 | Per-user installer, package lifecycle, signing parameters, hashes | Inno installer compilation and artifact checks; signed installation/release blocked pending T04 |
| T04 | Full Windows 11 acceptance **last** | Signed install/uninstall, actual context menu, multi-selection, drag, preview, real files/UNC, upgrade and UX |

## Gate
Merge stage code when CI build, compiler and isolated automatic tests pass with no known failure, and clearly carry physical tests into T04. A successfully compiled unsigned installer is not a usable release. No release/tag without explicit authorization.
