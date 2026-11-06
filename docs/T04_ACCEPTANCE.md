# T04 — Windows 11 final acceptance: PARTIALLY VERIFIED

The user has verified Windows 11 app installation, Explorer context-menu visibility and corrected Korean menu text. T04 also fixes a confirmed 0x800B0109 certificate issue and adds number-only renaming. Other GUI interactions, new branding and uninstall still require real Windows 11 evidence. CI on Windows Server cannot substitute for that evidence.

## Safety
Use a dedicated Windows 11 test account or disposable VM. Never perform test renames on personal files or production network shares. T04 test scripts do not touch existing user files.

## Test-only installer preparation (current)

For new tests, use the **[Git checkout and Windows 11 test kit](WINDOWS11_TEST_KIT.md)** instead of the historical version-specific artifact links. The kit downloads a successful main CI artifact matching the checked-out commit, checks the EXE's SHA-256, and for Explorer mode also checks the matching public development certificate and signed MSIX.

- **APP-ONLY**: installable unsigned GUI-only test setup; no Explorer registration or test-certificate import.
- **Explorer**: test-only signed installer requiring explicit approval and trust of the *matching* public CER in the disposable VM's LocalMachine TrustedPeople certificate store.
- Neither mode auto-runs an installer, imports a certificate or approves public release. Use only the isolated fixture files below.
- Record the local Git SHA, selected GitHub Actions run ID, certificate thumbprint and Windows build for acceptance.

## Generate disposable test files
From a checkout of the repository:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\New-TestFixtures.ps1

This creates a unique directory under %TEMP% with numeric filename samples, Unicode, spaces, two swap candidates and nested folders. It **never deletes or renames any existing files**. Record the printed directory path.

## Required interactive test matrix

| Case | Action on disposable fixtures | Expected outcome |
|---|---|---|
| 01 | Launch DK Easy Renamer | Branded app and **top-left titlebar icon**, with visible, clickable **minimize / maximize / restore / close** buttons; titlebar drag and resize remain functional |
| 01a | Maximize and restore the window, then minimize and reopen it from the taskbar | Window state changes appropriately without lost controls |
| 01b | Right-click two or more selected file rows, then choose remove | All selected rows disappear from the **program list only**; source files remain unchanged |
| 01c | Right-click included/excluded file rows and select include or exclude | Only selected rows change eligibility; preview and sequence numbering update |
| 01d | Right-click a rule row | Right-clicked rule becomes selected; enable/disable, move up/down and remove act on that rule |
| 02 | Right-click a single file in Explorer | One **DK Easy Renamer** root appears in Windows 11 *first-level* menu; expanding it shows editor, quick sequence and quick replace commands |
| 03 | Right-click several selected files, including Hangul/Japanese | Exactly selected paths are passed to one GUI |
| 04 | Right-click a folder | Folder itself is selected; children not separately renamed by default |
| 04a | Click '폴더 추가 ▾' and choose each source mode | Parent folder only / immediate files / recursive files / direct child folders match the chosen mode; adding does not rename |
| 04b | Add files recursively with junction/symlink child directories | Directory links are not traversed |
| 05 | Natural-sort file1, file2, file10 | Order 1,2,10 |
| 06 | Drag/reorder multiple rows and change a rule | Manual order remains stable |
| 07 | Number from 7 by 2 with width 3 | Preview 007,009,011 in eligible user order |
| 08 | Exclude a row | Excluded row consumes no sequence number |
| 08b | Sequence mode: replace original stem, 0 start, 1 increment, 2 digits | `18.svg`, `19.svg` preview as `00.svg`, `01.svg`; extension retained |
| 09 | Find/replace, case change, prefix/suffix | Correct preview; extension unchanged unless explicitly selected |
| 10 | Invalid regex or duplicate target | Error/collision shown; no overwrite or unwanted changes |
| 11 | Apply safe changes, then Undo | Original names and content restored |
| 12 | Rename file pairs as a swap, then Undo | No data loss and full restore |
| 13 | Light/dark UI, 125%–200% DPI | Layout, controls, text and focus usable |
| 14 | Restart Explorer and invoke again | Menu and app still function |
| 15 | Uninstall | Shell registration and app removed, test fixture files left intact |

Automated Windows Server GUI selection smoke also checks that the same disposable folder selected with and without a trailing separator appears only once in the WPF grid. This does not replace Windows 11 Explorer invocation acceptance.

For a dedicated test-only UNC share, test reading selected paths and, if safe, renaming copies of fixtures. Do not operate on real shares.

## Read-only registration checks

After installing:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Check-InstalledShell.ps1

This checks package, registry, native DLL, installed manifest and file signatures. It **does not prove Explorer menu behavior**; check that visually.

After uninstalling through Windows Installed apps:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Check-RemovedShell.ps1

If installation trust was added, after uninstall remove only that exact certificate:

    $testCert = Get-PfxCertificate .\DKEasyRenamer-TEST-ONLY.cer
    Remove-Item -LiteralPath ("Cert:\LocalMachine\TrustedPeople\" + $testCert.Thumbprint)

Do not remove unrelated certificates. The disposable test fixture remains until intentionally deleted.

## Evidence and exit gate

For each case record PASS, FAIL, or BLOCKED; Windows build, artifact ID and hash, certificate thumbprint, screenshots, error text and reproduction steps. Real device tests not run = **T04 BLOCKED**, not a pass. Production Release/tag remains prohibited pending complete acceptance and an appropriate public signing solution.

## Installation error diagnosis

An 'Explorer menu registration failed' dialog is a generic installer error, not the underlying Windows deployment code. Do not disable package signature verification or blindly trust certificates.

For the currently distributed installer, after dismissing the failed setup, run:

    Get-AppxLog | Select-Object -Last 15 TimeCreated, Id, Message | Format-List

Updated setup builds check the test certificate before copying application files and save any preflight errors at `%LOCALAPPDATA%\DK Easy Renamer\Logs\shell-preflight.log`. Registration errors are stored separately here:

    %LOCALAPPDATA%\DK Easy Renamer\Logs\shell-registration.log

Windows AppxLog from 2026-11-03 confirms 0x800B0109: the self-signed MSIX certificate was not trusted. The app files were copied even though registration failed because the earlier installer checked after copying. The updated installer checks before copying. The Local Machine Trusted People store is required for this App Installer case; importing only to Current User may not be sufficient. Verify the public .cer and the signed setup come from the same CI artifact before importing it. Each fresh CI run uses a different temporary test certificate. Other deployment errors need their actual code and activity log. Inspect before uninstall/cleanup.

Microsoft references:
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
- https://learn.microsoft.com/en-us/windows/win32/appxpkg/troubleshooting


## Windows 11 menu absent / COM activation denied (read-only probe)

The actual test PC shows package Status=Ok, manifest menu and COM entries, valid installer registry paths, but a manual PowerShell COM activation returned 0x80070005. This does **not** alone prove Explorer activation failed: activation context and permissions may differ.

After restarting Explorer and right-clicking a file, run from the checked-out T04 branch in **non-admin PowerShell**:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Diagnose-ExplorerCommand.ps1

This script prints package/COM metadata, existing app DLL signature, external folder ACL and recent Windows COM/AppModel events. It changes no Windows settings and does not create or rename files. Review the output for usernames and paths before sharing it.

PowerToys documents that MSIX ExternalLocation can alter folder DACLs on Windows 11 23H2/24H2. Such permissions are one hypothesis, not a confirmed cause. Do not modify ACLs, DCOM security or registry registration until the observed failure is established.

References:
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- https://github.com/microsoft/PowerToys/blob/main/src/PackageIdentity/readme.md

## Windows 11 menu title mojibake (2026-11-04)

After reboot the modern menu appears in both standard and extended Explorer context menus, but the Korean title is corrupt.
Root cause: ExplorerCommand::GetTitle() used a UTF-8 Korean string literal while the native MSVC C++ project did not specify /utf-8. BOM-less source can be misinterpreted in the builder's legacy code page.
Fix: enable /utf-8 for the native C++ project and use ASCII universal character escapes for the Korean title so its UTF-16 content does not depend on editor encoding.
Regression: Windows CI scans the built native COM DLL for the exact UTF-16LE title DK Easy Renamer로 이름 변경.
Actual Explorer rendering remains unverified until the rebuilt test installer is installed with the **matching certificate** and Explorer is restarted.


## Actual Windows 11 acceptance evidence (updated 2026-11-04)

User-confirmed physical observations, separate from CI:
- PASS: After explicitly trusting the development certificate, the application installed successfully.
- PASS: After reboot, the command appeared in both primary and extended Windows 11 file/folder context menus.
- PASS: The Unicode menu-title fix rendered readable Korean text in the real Explorer menu.
- NOT TESTED: Menu invocation with multi-select path handoff, live sorting/reordering, actual rename and Undo, updated light/dark readability, full update/uninstall.
- Provisioning pending: stable reusable development PFX and GitHub environment secrets (source-only workflow configured).

Do not mark T04 as fully accepted from these partial passes; use only disposable T04 fixture files for remaining operations.

## Window chrome and taskbar branding — T04 visual check (2026-11-04)

A physical test screenshot showed the old *DK letters on blue* taskbar icon although the main WPF UI used a document-and-pencil artwork. The older sparse package builder generated placeholder `Square44x44Logo.png`, used by the package identity for Windows taskbar. It is now resized from the same original PNG as the ICO, with transparent corners; the T05 package validator rejects the old opaque placeholder. The WPF window inherits the application's original ICO from the WPF ApplicationIcon build property.

The native caption previously displayed a blue title band without visible text, despite `Title=DK Easy Renamer` in XAML. `MainWindow.Caption.cs` now writes the title to the Win32 HWND and requests DWM white caption text on the #2D7BC6 caption, preserving Windows standard minimize/maximize/close controls. Test build version is incremented to **0.1.1** to distinguish the changed package assets from the old 0.1.0 install.

**To verify on Windows 11:** Install the new signed 0.1.1 probe using its corresponding trusted test certificate; close existing app windows, restart Explorer or sign out if an old icon is cached. Confirm (a) taskbar, titlebar and Start-menu icon use the document/pencil mark, (b) top native title reads `DK Easy Renamer` in white on blue, (c) basic minimize/maximize/close/drag behavior remains intact, and (d) Light/Dark theme switching still reads clearly. User-observed PASS/FAIL required; a passing image/COM build is not enough.


## Automated signed install/uninstall on Windows Server 2025 (2026-11-04)

CI now downloads the exact 0.1.1 signed installer and matching public certificate to a disposable Windows Server 2025 runner. It trusts the test certificate only on that runner, runs Inno Setup, verifies external app/COM/MSIX registration, runs uninstall, verifies package/registry/EXE removal and removes temporary certificate trust. [Windows Server 2025 smoke CI #41752486153](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41752486153): PASS.

The initial Server 2025 setup test was blocked at Inno PrepareToInstall because that runner's legacy Windows PowerShell could not load its security module. Setup now prefers already-installed PowerShell 7, otherwise uses the existing Windows PowerShell 5.1 fallback. It does not add a PowerShell 7 prerequisite for Windows 11.

This is automated Windows Server 2025 package lifecycle proof, NOT Windows 11 GUI acceptance. Taskbar icon, native caption and actual UI rename/Undo remain pending real Windows 11 observation.

## Automated implementation vs real Windows 11 acceptance

Implementation PR #6 can merge after automated gates. **This does not close Windows 11 acceptance.** The actual Windows 11 tasks remain in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7) until evidence is recorded; no public Release/tag or claim of complete readiness beforehand.


## CI integrated Explorer-selection GUI smoke (T04 follow-up)

The ephemeral Windows Server 2025 runner starts the installed WPF app with the same DKR1 UTF-16LE binary transport packet as the native Explorer COM verb. The script uses only newly generated test fixtures under TEMP (regular file, Korean and Japanese filenames, and an empty folder). Windows UI Automation checks all four paths appear in the live WPF FilesGrid, confirms the native title and consumed packet removal, and checks no test file contents changed on open. It closes only its own test process and deletes only its generated fixtures.

This is app-side handoff and GUI list evidence, not proof that the real Windows 11 shell menu invokes the COM command. Actual user-device menu invocation, Apply/Undo and light/dark visual appearance remain separate acceptance items.


## 2026-11-04: titlebar still blank and repeat signing certificate

The user reports that the native titlebar text is visually absent after installing 0.1.1, despite previous DWM text color calls. A nonempty Win32 window caption measured in Windows Server CI did not prove painted pixels. The follow-up now adds a real white WPF title text element in the blue WindowChrome caption area and keeps system caption button hit testing. UI Automation verifies the element is present and not offscreen; Windows 11 visual and window-control acceptance still requires a user-device observation.

The user also confirms that overwriting the same install folder does not prevent certificate trust errors. Each regular CI run generates a different self-signed signing identity; the folder cannot change Windows MSIX verification. The separate dev-signing workflow supports a persistent private PFX; owners must provision that key and GitHub protected environment exactly once (Configure-StableDevSigning.ps1 helps with secure local CLI input). Do not auto-import untrusted signing certificates.
