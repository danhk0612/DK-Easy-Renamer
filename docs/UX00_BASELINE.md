# UX-00 — Windows 11 real-device performance baseline

The baseline must be measured **before claiming speed improvements**. CI on Windows Server 2025 is not a substitute for user Windows 11 timing.

## No-change safety

The following script launches fresh **empty** DK Easy Renamer windows five times without selected paths and closes only the processes it opened. It does **not** rename, delete or inspect user files. Run with an installed, trusted test build and no unsaved work in the newly launched windows:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Measure-WindowsLaunch.ps1

It reports milliseconds between the operating system process start call and availability of the application's main HWND, with median/min/max and Windows build. It **does not** include first-level Explorer context menu visibility, Windows graphics paint, or an actual user interaction. First call may be cold-ish but not a reproducible fully cold start.

## Manual stopwatch / screen-recording metrics

With a disposable T04 fixture directory (tools/t04/New-TestFixtures.ps1), record 5 attempts each. Note file count, SSD/UNC, Windows build, screen DPI and warm/cold startup explicitly:

| Case | Start | End | Existing 0.1.1 baseline | New quick-menu build |
|---|---|---|---|---|
| Single file initial context menu | Right click | Modern menu appears | BLOCKED (user measure) | BLOCKED |
| 20-file context menu | Right click selection | Modern menu appears | BLOCKED | BLOCKED |
| Standard editor invocation | Click existing Explorer command | WPF table visible | BLOCKED | BLOCKED |
| Quick submenu open | Click quick group | Children visible | N/A | BLOCKED |
| Quick sequence/replace invoke | Click respective child | WPF table with rule visible | N/A | BLOCKED |
| 500/5000 fixture preview | Change a rule field | Preview/status updates | BLOCKED | BLOCKED |

Avoid running rename tests on personal or network files. For bulk tests use a unique disposable directory and clearly separate network results from local SSD. On a slow machine, 5000 fixture creation itself may be expensive. No pass/fail performance threshold is claimed without a baseline.

## Constraints

- Keep original top-level command visible and accessible with no extra submenu click.
- Do not add synchronous user configuration reading or file metadata enumeration to Explorer's GetState, GetTitle or EnumSubCommands.
- Compare same machine, build, file set and number of measurements.
- Actual file Apply/Undo and high-DPI visuals still require issue #7 Windows 11 signoff.
