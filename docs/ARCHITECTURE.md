# Architecture v1.0

## Logical components
1. `DK.EasyRenamer.App` — WPF presentation, desktop entry point, rule-editing UI, preview and status, no direct filesystem mutation in view code.
2. `DK.EasyRenamer.Core` — future rename models, stable ordered selection, deterministic rules, validation, execution and undo journal (T02).
3. `DK.EasyRenamer.Shell` — future native x64 COM `IExplorerCommand` extension and handoff to App (T01).
4. `installer/` — per-user Inno Setup with sparse identity package registration/unregistration. T05 automated build, T04 physical verification.
5. `tests/` — hermetic core tests plus Windows-specific integration validation.

## Core invariants
- User order (manual/selected sort) is authoritative; recompute names without reordering rows.
- Same immutable plan feeds preview and execution after final freshness/conflict validation.
- No silent overwrite, destructive collision resolution, hidden recursion or extension change.
- Filesystem writes occur only after the user explicitly requests Apply.
- COM menu callbacks must not parse file content or block Explorer; communicate selection to the app only.
- Windows path/Unicode/case-insensitive file system behavior must be covered by real tests.

## Implementation status
T00–T03 are merged with WPF-UI, native shell extension, Core planner/executor and disposable fixture tests. T05 packages the win-x64 app self-contained with package identity, but Windows 11 installed/interactive behavior is not yet verified.

## Dependency direction
`App -> Core`; `Core -> (no App/Shell references)`; `Shell -> launch/transport contract for App`. Do not make Core depend on the Explorer process or WPF.

## Sources
- Modern menu registration: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- WPF UI package: https://www.nuget.org/packages/WPF-UI (MIT, candidate 4.3.0 checked 2026-11-03).
