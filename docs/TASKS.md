# Tasks — sequential delivery baseline

**Status as of 2026-11-03:** T00 implementation submitted in [PR #1](https://github.com/danhk0612/DK-Easy-Renamer/pull/1) from `work/t00-project-foundation`. First Windows CI run [#1](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41586083088) passed restore, build (0 compiler warnings/errors) and 2/2 tests. The later CI action-version update requires revalidation on the final commit. Manual GUI startup has not been verified. T01–T05 have not started.

| Task | Purpose | Completion evidence | Not in scope |
|---|---|---|---|
| **T00** | Repository init, MIT, AGENTS/docs, .NET10 WPF/Core/test project, Windows CI | restore/build/test on Windows, documented gaps, review PR | working rename, shell extension, final GUI/installer |
| **T01** | Modern Windows 11 Explorer command proof | real first-level menu and multi-selection handoff, repeatable packaged registration | rename engine |
| **T02** | Deterministic rename engine | unit and filesystem fixture tests, safe planner/apply/undo | final GUI |
| **T03** | Fluent GUI, ordered list, graphical rules, app icon/themes | manual UX and accessibility verification | distribution |
| **T04** | Integrate and verify | actual Windows 11 acceptance suite with evidence | new unrelated features |
| **T05** | Installer and public deliverables | fresh PC install/upgrade/remove and packaging/signing review | new product features |

## Task workflow
1. Read `AGENTS.md` and all relevant docs, inspect latest `main`.
2. Create task branch. Implement only the assigned task.
3. Run task-specific checks, update evidence and task status honestly.
4. Commit/push and create PR; no automatic merge or release.
5. Start the next task only after the previous task has been reviewed and merged (unless explicit coordination overrides this).

## T00 review checklist
- [x] GitHub repository initialized with MIT license and requirements/design/architecture/shell/test/task documents.
- [x] .NET 10 WPF/Core/test source skeleton and Windows build workflow authored.
- [x] At least one Windows CI restore/build/test run completed successfully (run #1, 2026-11-03).
- [x] PR #1 submitted and awaiting review.
- [ ] Current PR head CI revalidation after action upgrades/docs update.
- [ ] Actual Windows 11 GUI launch/visual sanity check (not possible via headless CI).
