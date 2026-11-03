# DK Easy Renamer

A focused Windows 11 batch file/folder renamer with precise ordering and GUI-driven rename rules.

> **Status:** T00 foundation only. The current app is a non-operational UI shell. It does **not** rename files, integrate with File Explorer, or install shell extensions yet.

## Product goals

- Rename files and folders selected in Windows 11 File Explorer.
- Arrange items by natural name, date, size, or manual drag/drop ordering, and apply numbering in exactly that order.
- Compose rename rules with explicit GUI controls; regex is optional advanced functionality.
- Preview the exact proposed changes, detect collisions, apply safely, and undo completed actions.
- Use a Fluent-inspired visual system with primary accent `#2D7BC6`, light/dark themes and accessible controls.
- Run locally without an account, backend or resident service.

## Technology baseline

- C# / .NET 10 LTS; WPF desktop app on Windows 11 x64.
- WPF UI (Fluent) is planned for T03 after shell/engine foundations are validated.
- Native `IExplorerCommand` COM extension with package identity for the modern Windows 11 context menu (T01 proof of concept).
- MIT license. All external dependency licenses must be recorded before distribution.

## Local development

On Windows 11 with the .NET 10 SDK:

```powershell
dotnet restore .\DK-Easy-Renamer.sln
dotnet build .\DK-Easy-Renamer.sln -c Release --no-restore
dotnet test .\DK-Easy-Renamer.sln -c Release --no-build
dotnet run --project .\src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj
```

The CI pipeline builds/tests on a Windows x64 runner. For local shell extension tests and install/uninstall verification see `docs/SHELL_INTEGRATION.md` (T01 onward).

## Documents

- [Requirements](docs/REQUIREMENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Shell integration](docs/SHELL_INTEGRATION.md)
- [Test plan](docs/TEST_PLAN.md)
- [Task plan](docs/TASKS.md)
- [Contributor/agent instructions](AGENTS.md)

## License

MIT — see [LICENSE](LICENSE).
