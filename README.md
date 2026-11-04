# DK Easy Renamer

A focused Windows 11 batch file/folder renamer with precise ordering and GUI-driven rename rules.

> **Status (2026-11-04):** T00–T03 are merged. T05 builds a per-user self-contained Windows setup with Sparse MSIX identity registration; unsigned CI candidates are deliberately **non-installable**. Actual signed installation, first-level Explorer menu and end-to-end UI are unverified until T04.

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
- [Task plan](docs/TASKS.md)
- [Contributor/agent instructions](AGENTS.md)

## Windows installer candidate

A self-contained Windows 11 x64 setup can be compiled after the native C++ build using `tools/t05/Build-Distribution.ps1` (Inno Setup 6 required). CI creates both a blocked `UNSIGNED-DO-NOT-INSTALL` candidate and a separate **test-only `SIGNED-PROBE`** installer with a public development certificate (private signing key never uploaded). Neither is a public release; see [T05 CI #30](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41597002092). For the signing contract, per-user registration, hashes and final verification see [the installer guide](docs/INSTALLER.md).

## License

MIT — see [LICENSE](LICENSE).

### Latest T04 visual fixes (test build 0.1.1)

The sparse MSIX taskbar logo and native WPF window caption now match the original document/pencil branding: no temporary `DK` logo, and `DK Easy Renamer` title displayed with white text on a blue native title bar. See the [T04 implementation PR](https://github.com/danhk0612/DK-Easy-Renamer/pull/6) and [Windows 11 acceptance checklist](https://github.com/danhk0612/DK-Easy-Renamer/issues/7). Windows 11 visual acceptance remains to be confirmed before a production release.

**0.1.1 automated verification:** [Windows CI + signed install/uninstall smoke](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41753265249) passed. Windows 11 taskbar/icon/titlebar visual review and rename/Undo workflow acceptance are tracked in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7).


### UX-00/UX-01/UX-07 test build (0.1.2)

- Existing Explorer rename entry remains present. Additional quick actions are grouped under a separate Explorer submenu for sequence and find/replace; WPF still previews and requires confirmation.
- Users can manually check for new public stable GitHub Releases via the in-app **업데이트 확인** button. No automatic download or install; see issue #10.
- Application and installer versions are both raised to **0.1.2** for accurate MSIX sparse identity upgrade validation.
- Windows Server 2025 CI checks launch, quick-mode handoff, package registration and uninstall. Windows 11 menu layout and actual Apply/Undo still require issue #7 approval.
- Use a manually dispatched GitHub workflow with stable_dev_signing=true to obtain a test installer signed with the existing persistent development certificate. Ordinary PR certificates rotate.
