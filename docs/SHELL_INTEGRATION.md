# T01 — Windows 11 Modern Context Menu Integration

## Current state: automated gate passed, physical acceptance deferred
T01 supplies native `IExplorerCommand`, sparse package manifest, per-user development scripts, UTF-16LE selection handoff and WPF receiver.

**CI:** https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41588917742 — WPF/Core Release build, 7/7 tests, native x64 COM DLL, publish and unsigned sparse package all succeeded, zero warnings/errors.

**Deferred to T04/T05:** actual first-level Explorer menu visibility, exact selected paths delivered by clicking Explorer, signed development package install/upgrade/remove, Explorer refresh and normal-user permissions. These are **unverified**, not a pass or a waived requirement.

## Components and protocol
- Native x64 COM: `src/DK.EasyRenamer.Shell/ExplorerCommand.cpp`.
- CLSID: `73F9A0E1-982D-4C4E-AB20-987DCA14E930`, shared with `installer/shell/AppxManifest.xml`.
- `Invoke` gets `SIGDN_FILESYSPATH` entries from `IShellItemArray`.
- Packet: ASCII `DKR1`, uint32 LE count, per path uint32 UTF-16 code-unit count plus UTF-16LE bytes.
- WPF `--selection-file` receives `DKR*.tmp` in user temp, shows paths in order and deletes only the temporary handoff packet. No rename operations in T01.
- HKCU development settings: `Software\DKEasyRenamer\ExecutablePath` and `IconPath`.
- Sparse package uses `windows.comServer`, `windows.fileExplorerContextMenus` (file and Directory), `uap10:AllowExternalContent`. External app directory contains DLL and temporary images.

## Development build on Windows 11 x64
Requires .NET 10 SDK, Visual Studio C++ Build Tools v143, Windows SDK and PowerShell.

```powershell
dotnet restore .\DK-Easy-Renamer.sln
dotnet build .\DK-Easy-Renamer.sln -c Release --no-restore
dotnet test .\DK-Easy-Renamer.sln -c Release --no-build
# Invoke MSBuild from Visual Studio developer prompt, or via vswhere.
msbuild .\src\DK.EasyRenamer.Shell\DK.EasyRenamer.Shell.vcxproj /p:Configuration=Release /p:Platform=x64
dotnet publish .\src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj -c Release -r win-x64 --self-contained false -o .\artifacts\t01\app
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Build-SparsePackage.ps1
```

## T04 manual registration and acceptance checklist (deferred)
Development machine only; explicitly creates/trusts a *per-user* self-signed test certificate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Register-Dev.ps1 -CreateDevCertificate -TrustDevCertificate
Get-AppxPackage -Name DKEasyRenamer.Shell
# Test first-level menu on files, folders, multi-selection, Korean/Japanese/UNC/spaces; check exact path count and order.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Unregister-Dev.ps1
```

After removal, ensure package and menu are absent; restart Explorer or sign out/in if necessary. Development trust certificates are not silently deleted.

## References
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
- https://github.com/microsoft/PowerToys/blob/main/doc/devdocs/common/context-menus.md
