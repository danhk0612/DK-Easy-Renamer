# T01 — Windows 11 Modern Context Menu Integration

## Current state
Source and CI scaffolding: native IExplorerCommand, sparse identity manifest, per-user development scripts, binary selection handoff and WPF selection receiver.

**Not verified by source/CI alone:** Windows 11 first-level Explorer menu visibility, actual selection launch, signed package install/uninstall, and shell refresh behavior. Do not mark T01 complete without real Windows 11 evidence.

## Components and protocol
- Native x64 COM: src/DK.EasyRenamer.Shell/ExplorerCommand.cpp.
- CLSID: 73F9A0E1-982D-4C4E-AB20-987DCA14E930, identical to installer/shell/AppxManifest.xml.
- Invoke obtains SIGDN_FILESYSPATH from the selected IShellItemArray.
- Packet: bytes DKR1, uint32 little-endian count, then per path uint32 UTF-16 code-unit length plus UTF-16LE bytes.
- WPF --selection-file accepts DKR*.tmp in the user's temp directory, displays the selected paths in order, and deletes only the temporary packet. No renames.
- Per-user HKCU\Software\DKEasyRenamer settings ExecutablePath and IconPath are development-only.
- Sparse identity package uses windows.comServer, windows.fileExplorerContextMenus for * and Directory, and uap10:AllowExternalContent. COM DLL and imagery are placed in the external app location rather than inside the identity MSIX.

## Windows 11 x64 development build
Needs .NET 10 SDK, Visual Studio C++ build tools v143, Windows 10/11 SDK, PowerShell:

    dotnet restore .\DK-Easy-Renamer.sln
    dotnet build .\DK-Easy-Renamer.sln -c Release --no-restore
    dotnet test .\DK-Easy-Renamer.sln -c Release --no-build
    msbuild .\src\DK.EasyRenamer.Shell\DK.EasyRenamer.Shell.vcxproj /p:Configuration=Release /p:Platform=x64
    dotnet publish .\src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj -c Release -r win-x64 --self-contained false -o .\artifacts\t01\app
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Build-SparsePackage.ps1

Produces an unsigned development identity MSIX, not a ready-to-install signed installer.

## Explicit developer registration (test PC only)
This command explicitly creates and trusts a dedicated self-signed *per-user* dev certificate:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Register-Dev.ps1 -CreateDevCertificate -TrustDevCertificate
    Get-AppxPackage -Name DKEasyRenamer.Shell

On actual Windows 11, right-click files/folders and verify first-level entry, multi-selection, Korean/Japanese filenames, spaces, UNC and exact path display. Repeat after Explorer restart. Confirm no file change.

Unregister:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t01\Unregister-Dev.ps1

Verify Get-AppxPackage returns no package and menu is gone. The development certificate is intentionally left untouched and must be manually revoked if no longer trusted.

## Sources
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
- https://github.com/microsoft/PowerToys/blob/main/doc/devdocs/common/context-menus.md
