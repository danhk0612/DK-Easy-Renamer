# Optional Windows 11 Explorer context menu

## Intent

The WPF batch renamer is a standalone Windows desktop application. Its modern Windows 11 first-level context menu uses an optional, separately registered, signed sparse MSIX identity and the native IExplorerCommand DLL.

**Installing the base application must not depend on a trusted MSIX certificate.** A failed or untrusted certificate disables only optional Explorer registration; it does not add trust, copy certificates to a store, or silently fall back to a legacy context menu.

## Installation behavior

- **Unsigned / APP-ONLY:** `tools/t05/Build-Distribution.ps1 -AppOnly` builds an explicitly unsigned standalone test installer. No Explorer menu task is provided; the WPF app can launch directly. This build is not approved for public distribution. Windows SmartScreen or Smart App Control may warn or block unsigned installers.
- **Signed / SIGNED-PROBE:** Inno Setup displays an *unchecked* `Windows 11 탐색기 우클릭 메뉴 등록` task. When the matching MSIX certificate is not trusted, this checkbox is visibly disabled and unchecked. The WPF application can still be installed.
- **Silent install:** `/TASKS=shellmenu` explicitly opts in. The certificate is checked again before any installation files are copied; if it is untrusted, that particular opt-in installation is rejected. Omit the task to install only the app.
- The previous `UNSIGNED-DO-NOT-INSTALL` CI packaging candidate remains deliberately blocked; it is not the APP-ONLY installer.
- On reinstall/upgrade, **unchecking** the optional task removes an existing menu registration belonging to the same install path without removing the application.

## In-app context menu controls

The header has a **우클릭 메뉴 적용 / 해제** button.

- **Active:** remove the current user's matching sparse MSIX package registration and registry values without uninstalling the app.
- **Available:** confirm the action, then run the installed `Register-Shell.ps1` script. It rechecks package trust and lets Windows validate the package. No certificate is automatically imported.
- **Unavailable:** disabled if unsigned/untrusted MSIX or required installed scripts are missing. A changed certificate trust state is picked up when the app is relaunched.
- **Conflict:** disabled when the current user's Explorer registration belongs to a different installation path.
- Explorer may need a manual refresh/restart or sign-out/sign-in for menu changes to appear.

The installed `Query-ShellState.ps1` reports current-user state; only the user's button starts registration/removal. No background agent, admin elevation request, or automatic certificate import is added.

## Windows CI verification

- Existing signed installation and same-certificate test upgrades explicitly opt into `/TASKS=shellmenu` so their expected Explorer registration continues to be checked.
- A separate disposable Windows Server 2025 VM runs `Smoke-OptionalShellOnRunner.ps1` with: unsigned APP-ONLY installation (no certificate), signed installer installation with untrusted certificate (app only), temporary certificate trust on **that VM only**, explicit shell installation, removal and re-application using the installed scripts, and uninstall cleanup.
- Windows Server checks do not establish that the interactive Inno checkbox or WPF button visually behaves correctly on Windows 11. Keep the physical acceptance item open until directly observed.

## Release boundaries

Do not publish unsigned or development-signed test installers as public releases. Public signing identity, trust-chain verification, SmartScreen reputation, Windows 11 usability verification and the application updater's public-signing gate remain separate work.
