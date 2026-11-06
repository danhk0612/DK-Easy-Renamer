# DK Easy Renamer

A focused Windows 11 batch file/folder renamer with precise ordering and GUI-driven rename rules.

> **Status (2026-11-06):** Current tested application version: **0.1.2**. The Windows 11 GUI and three-action Explorer flyout were user-checked; file- versus folder-specific submenu labels were implemented in PR #47 and passed native COM CI, with additional manual testing explicitly skipped. Development-signed installers are **TEST-ONLY**, not public releases. GitHub Releases distribution using a **Korean individual developer's CA-issued code-signing identity** is the selected release direction; provider, legal publisher subject, cost and first public release are pending. See the [public GitHub release plan](docs/PUBLIC_GITHUB_RELEASE_PLAN.md).

## Product goals

- Rename files and folders selected in Windows 11 File Explorer.
- Arrange items by natural name, date, size, or manual drag/drop ordering, and apply numbering in exactly that order.
- Compose rename rules with explicit GUI controls; regex is optional advanced functionality.
- Preview the exact proposed changes, detect collisions, apply safely, and undo completed actions.
- Use a Fluent-inspired visual system with primary accent `#2D7BC6`, light/dark themes and accessible controls.
- Run locally without an account, backend or resident service.

## Technology baseline

- C# / .NET 10 LTS; WPF desktop app on Windows 11 x64.
- WPF UI (Fluent) 4.3.0 is integrated into the T03 GUI.
- Native `IExplorerCommand` COM extension with package identity for the modern Windows 11 context menu (T01 proof of concept).
- MIT license. All external dependency licenses must be recorded before distribution.

## Implemented Core (T02)

- Rename rules, natural sorting, deterministic preview, collision avoidance, two-phase rename and same-session undo.
- Unit and disposable-directory filesystem tests: **19/19** in [Windows CI run #14](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41590420863).
- The Core engine is wired to the WPF rule editor, live preview, apply and undo UI. Nested directory plus its child in one batch is rejected for safety; see [engine design](docs/RENAME_ENGINE.md).
- Physical Windows 11 integration acceptance is deferred to T04, not waived.

## Test on Windows 11 from Git (test artifacts, not a public release)

The current [Windows 11 test kit](docs/WINDOWS11_TEST_KIT.md) describes both an **APP-ONLY** installer with no test-certificate requirement, and a separate **development-signed Explorer** installer. From an updated main checkout with authenticated GitHub CLI:

```powershell
git checkout main
git pull --ff-only
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Get-Windows11TestBuild.ps1 -Mode AppOnly
```

Use `-Mode Explorer` only in a disposable Windows 11 VM after reviewing and explicitly trusting the matching public development certificate. The script verifies the exact Git commit, successful CI, artifact hash and signer (when signed), but **never installs or modifies certificate trust**. Test artifacts are not production installers. Completed user checks and the last untested version of the file/folder-specific menu labels are tracked in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7).

## Local development

On Windows 11 with the .NET 10 SDK and PowerShell, generate the original app icon before building:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t03\Generate-Icon.ps1
dotnet restore .\DK-Easy-Renamer.sln
dotnet build .\DK-Easy-Renamer.sln -c Release --no-restore
dotnet test .\DK-Easy-Renamer.sln -c Release --no-build
dotnet run --project .\src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj
```

The GUI uses WPF-UI 4.3.0 (MIT). All user-facing renaming actions require a separate confirmation. The CI pipeline builds/tests on a Windows x64 runner. For local shell extension tests and install/uninstall verification see `docs/SHELL_INTEGRATION.md` (T01 onward).

## Documents

- [Requirements](docs/REQUIREMENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Shell integration](docs/SHELL_INTEGRATION.md)
- [Test plan](docs/TEST_PLAN.md)
- [Rename engine](docs/RENAME_ENGINE.md)
- [GUI design and implementation](docs/UI_IMPLEMENTATION.md)
- [Installer / distribution](docs/INSTALLER.md)
- [GitHub Releases / Korean individual developer signing plan](docs/PUBLIC_GITHUB_RELEASE_PLAN.md)
- [Release readiness audit](docs/RELEASE_READINESS_2026-11-06.md)
- [Task plan](docs/TASKS.md)
- [Contributor/agent instructions](AGENTS.md)

## Windows installer candidate

A self-contained Windows 11 x64 setup can be compiled after the native C++ build using `tools/t05/Build-Distribution.ps1` (Inno Setup 6 required). CI creates both a blocked `UNSIGNED-DO-NOT-INSTALL` candidate and a separate **test-only `SIGNED-PROBE`** installer with a public development certificate (private signing key never uploaded). Neither is a public release; see [T05 CI #30](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41597002092). For the signing contract, per-user registration, hashes and final verification see [the installer guide](docs/INSTALLER.md).

## License

MIT — see [LICENSE](LICENSE).

### Historical T04 visual fixes (test build 0.1.1)

The sparse MSIX taskbar logo and native WPF window caption now match the original document/pencil branding: no temporary `DK` logo, and `DK Easy Renamer` title displayed with white text on a blue native title bar. See the [T04 implementation PR](https://github.com/danhk0612/DK-Easy-Renamer/pull/6) and [Windows 11 acceptance checklist](https://github.com/danhk0612/DK-Easy-Renamer/issues/7). The branding was subsequently user-checked on Windows 11. This subsection documents the older 0.1.1 test build, not the current release candidate.

**0.1.1 automated verification:** [Windows CI + signed install/uninstall smoke](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41753265249) passed. Windows 11 visual and rename/Undo user feedback is recorded in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7).


### UX-00/UX-01/UX-07 test build (0.1.2)

- The Windows 11 Explorer right-click integration exposes **one DK Easy Renamer flyout** with rename, quick sequence, and quick find/replace commands. As of PR #47, the three labels are separately tailored to files versus folders. WPF still previews and requires confirmation.
- Users can manually check for new public stable GitHub Releases via the in-app **업데이트 확인** button. Verified download/install code exists, but **public in-app installation stays disabled** until an approved publisher and signed release; see issue #10.
- Application and installer versions are both raised to **0.1.2** for accurate MSIX sparse identity upgrade validation.
- Windows Server 2025 **PR CI** checks launch, quick-mode handoff, package registration, uninstall and upgrade. Main push CI builds packages but skips PR-only Windows Server install jobs. Windows 11 previous flyout/UI functions were user-checked; latest file/folder-specific menu labels were auto-checked only.
- Use a manually dispatched GitHub workflow with stable_dev_signing=true to obtain a test installer signed with the existing persistent development certificate. Ordinary PR certificates rotate.

### UX-07 safety and public-release status (2026-11-06)

- PRs #19–#22 implement guarded official Release download, SHA-256 and pinned Authenticode verification, explicit install approval, single-use installer handoff/cleanup, and CI-only signed test-fixture regression checks.
- PRs #23–#25 guard mismatched MSIX publishers and provide read-only pre-migration diagnostics. A publisher switch changes package identity and is **not** automatically migrated or removed.
- PRs #26–#27 provide separate, opt-in local-data snapshot and old signed EXE/MSIX archive rehearsal tools. They do **not** install, unregister, migrate, or roll back a live application.
- Remaining **public-release** gates: obtain an approved individual CA signing identity; sign aligned EXE/DLL/MSIX/Setup packages; verify actual public-signature Windows 11 install, uninstall, upgrade, publisher migration and recovery. Existing dev-signed GUI/Explorer checks do not waive those gates. See [issue #10](https://github.com/danhk0612/DK-Easy-Renamer/issues/10), [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7), [public release plan](docs/PUBLIC_GITHUB_RELEASE_PLAN.md), and [rollback archive guide](docs/UX07_SIGNED_ROLLBACK_ARCHIVE.md).
- No public Release or tag is authorized by automated CI success alone.
