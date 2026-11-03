# DK Easy Renamer — contributor/agent contract

## Fixed product decisions
- Name: **DK Easy Renamer**; repository `danhk0612/DK-Easy-Renamer`; license **MIT**.
- Target: **Windows 11 x64**, initially Korean UI; modern first-level Explorer context menu is a v1.0 requirement, not the legacy-only submenu.
- Foundation: C# / .NET 10 LTS, WPF. Fluent/WPF UI integration belongs to T03; native COM `IExplorerCommand` spike belongs to T01.
- Visual identity: `#2D7BC6` primary. Icons must be coherent, readable at small sizes, and distributable with license compliance.
- The product is local-only: no servers, tracking, resident agents or cloud dependencies.
- Rename rule UI must not require reading docs or typing magic expressions for ordinary actions.
- Manual item order is an independent, stable sequence; numbering follows the current displayed user order.

## Working policy
1. Read this file, `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md` before changes.
2. Work **one task at a time** and respect the task scope; do not implement subsequent tasks implicitly.
3. Create task-specific branches and PRs. User authorized merging a stage after its automated gate passes and known code failures are resolved (2026-11-03). Do not publish a release/tag without an explicit request.
4. When modifying behavior, add focused automated tests and update corresponding specs/verification notes.
5. Never run destructive tests against a real user directory; use ephemeral test fixtures. Do not overwrite or silently skip conflicts.
6. Keep `Core` OS-UI-independent where practical. Keep native Explorer COM callbacks very light.
7. Distinguish verified behavior from intended behavior: modern Explorer menu, installed shell extension and real-user workflow remain unverified until T04. Engine apply/undo is verified only in isolated automated filesystem fixtures.
8. A failed validation is a blocker to report, not a reason to mark the task complete.

## Stage boundaries
- **T00:** Empty repository initialization, minimal compiling WPF/Core/test solution, MIT, docs and Windows CI. No rename operations or shell extension.
- **T01:** Implement native Explorer menu/selection handoff and unsigned package, CI gate passed. Real registration/click tests deferred to T04.
- **T02:** Implement rename rules, ordered planning, validation, filesystem apply/undo and automated tests. UI wiring belongs to T03.
- **T03:** Implement GUI, manual ordering, rule editing, WPF-UI theme and icon. CI compile and Core tests run now; actual visual and interactive workflow acceptance is deferred to T04 by user request.
- **T04:** End-to-end Windows 11 validation.
- **T05:** Installer, lifecycle, distribution and release evidence.
