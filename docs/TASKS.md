# Tasks — sequential delivery baseline

**2026-11-03:** T00 merged via PR #1. T01 native code/selection handoff and sparse package compile successfully with CI run #9 (7/7 tests, zero warnings/errors). User requested **deferral of physical Windows 11 testing until late integration**, so T01 is accepted provisionally on automated evidence and physical Explorer verification is mandatory in T04/T05. T02 next.

| Task | Scope | Acceptance gate |
|---|---|---|
| T00 | Foundation and CI | PR #1 merged; build/test passed |
| T01 | Native first-level Explorer command and selection transport | CI build/test/unsigned package; physical integration carried as an explicit T04 blocker |
| T02 | Deterministic rename engine | plan, validate, apply, undo with disposable filesystem tests |
| T03 | Fluent UI, ordered list, GUI rules, icon/theme | UI build and automated checks; manual visual pass carried to T04 |
| T04 | Actual Windows 11 integration/acceptance | Explorer context menu, multi-select, install/undo, path/Unicode/UNC, UI tests on real desktop |
| T05 | Installer and final delivery | signed install, update, removal and release verification |

## Stage policy
1. Implement and validate in sequence. Use automated tests/Windows CI early; defer actual interactive device tests until T04 when feasible.
2. Merge when the current coding/automated gate passes, while documenting all unverified platform behavior and carrying it into T04/T05. **A green CI does not prove a modern Explorer menu works**.
3. If code itself is failing CI or a known safety issue exists, do not merge.
4. Publishing a release or claiming operational Windows support still requires all final physical tests.
5. User authorized routine stage merges without further approval on 2026-11-03, and subsequently authorized deferral of physical tests.
