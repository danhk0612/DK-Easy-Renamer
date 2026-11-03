# T05 — Windows 11 installer and distribution (automated build)

## Packaging choice
- **Per-user Inno Setup 6 installer**, Windows 11 x64 only. Default destination: the current user's LocalAppData\Programs\DK Easy Renamer. No UAC required for ordinary use.
- **Self-contained .NET 10 win-x64 WPF application**, no separate .NET Desktop Runtime download required.
- **Native IExplorerCommand DLL** plus **Sparse MSIX** identity registered via Add-AppxPackage -ExternalLocation. Manifest logos, COM DLL, EXE and application icon remain beside the EXE.
- Installer copies the app and identity package, calls Register-Shell.ps1 as the same user, creates Start Menu shortcut, and calls Unregister-Shell.ps1 before uninstalling program files. Failure to register/remove raises an installer error; no silent false success.
- No tracking, network services or post-install app launch required.

## Signing and release boundary
A trusted certificate is a hard requirement for a functioning installed Explorer extension. It must match both the MSIX manifest Publisher and the EXE's embedded msix publisher.

Without a signing certificate, Build-Distribution.ps1 creates an **UNSIGNED-DO-NOT-INSTALL** installer candidate. It compiles and its files are inspectable, but its InitializeSetup deliberately blocks installation. No trusted certificate or password is generated, stored or embedded in GitHub Actions.

Optionally provide -Publisher 'CN=<actual certificate Subject>' and -CertificateThumbprint '<cert in CurrentUser/My with private key>' to sign the external EXE, native DLL, MSIX and outer installer. The certificate must be trusted by the target Windows account. The signed output remains a **SIGNED-PROBE** pending real installation, signature verification and uninstaller signing/reputation review. Do not publish to users from CI.

A temporary self-signed certificate is acceptable only on an isolated test machine with explicit trust. Public distribution requires a trusted signing solution; a new publisher may still trigger SmartScreen warnings until reputation is established.

## Automated Windows CI
The Windows GitHub Actions job performs:
1. Standard T00–T03 icon generation, WPF/Core tests and C++ COM build.
2. Install/find the Inno Setup 6 compiler, build the self-contained app with consistent identity metadata.
3. Package the identity-only MSIX; assemble installer and copy LICENSE and THIRD_PARTY_LICENSES.
4. Verify required files, parse PowerShell scripts, validate identity match and package ZIP, and check SHA-256 hashes.
5. Upload separately labeled **unsigned candidate** artifacts. No installer execution and no Explorer registration occur in CI.

Run locally on Windows 11 with .NET 10 SDK, C++ Build Tools / Windows SDK and Inno Setup 6:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t03\Generate-Icon.ps1
    # Build C++ COM DLL as in docs/SHELL_INTEGRATION.md.
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t05\Build-Distribution.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t05\Validate-Distribution.ps1

Output: artifacts/t05/installer/DK-Easy-Renamer-0.1.0-x64-UNSIGNED-DO-NOT-INSTALL.exe, artifacts/t05/DKEasyRenamer.Shell.msix, SHA256SUMS.txt.

For a signed local test build, call Build-Distribution.ps1 with -Publisher matching the exact code-signing cert subject and -CertificateThumbprint, then explicitly trust the certificate on that test machine before installation. Never put signing private keys or passwords in the repository.

## Mandatory T04 real-device acceptance
- On Windows 11 x64 ordinary user: signed probe setup installs without privilege elevation, exact package identity and first-level Explorer action appears.
- Files/folders/multiselection and Korean/UNC names are delivered to GUI. Rename/apply/undo and manual ordering work.
- Install path with spaces and Hangul, update of an older version, changed install directory and repeat installer behavior.
- Uninstall removes package and HKCU command values; no orphan Explorer menu; application files are removed without touching user files.
- App is correctly recognized in Windows Installed apps and Start Menu, has the right icon, and light/dark UI remains usable.
- Signing trust, binary/publisher alignment, installer/uninstaller signature and SmartScreen behavior verified.
- Reject unsigned candidate installer; verify hashes; verify user data not removed.

If any real-world test fails, repair it in T04 before publishing. T05 is not release approval.

## References (checked 2026-11-03)
- Microsoft: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
- Microsoft: https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windows-11
- Inno: https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm
- Inno: https://jrsoftware.org/ishelp/topic_scriptevents.htm
