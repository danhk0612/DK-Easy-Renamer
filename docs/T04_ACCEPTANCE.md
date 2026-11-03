# T04 — Windows 11 final acceptance: NOT YET EXECUTED

The T00–T05 code builds; T04 fixes a confirmed 0x800B0109 certificate failure, number-only sequence mode and light-mode contrast. CI runs on Windows Server and cannot prove the Windows 11 Explorer first-level context menu or WPF interactions actually work. Only actual Windows 11 x64 test evidence can close T04.

## Safety
Use a dedicated Windows 11 test account or disposable VM. Never perform test renames on personal files or production network shares. T04 test scripts do not touch existing user files.

## Test-only installer preparation
1. Download the artifact **t05-DEV-SIGNED-TEST-ONLY-MANUAL-TRUST** from the latest passing Windows CI of this repository. It includes DK-Easy-Renamer-0.1.0-x64-SIGNED-PROBE.exe, a public test certificate DKEasyRenamer-TEST-ONLY.cer, and SHA256SUMS.txt.
2. Check the SHA-256 hash, verify the file origin and compare the thumbprints:

    Get-AuthenticodeSignature .\DK-Easy-Renamer-0.1.0-x64-SIGNED-PROBE.exe | Format-List Status,SignerCertificate
    Get-PfxCertificate .\DKEasyRenamer-TEST-ONLY.cer | Format-List Subject,Thumbprint,NotAfter

3. Only on an isolated Windows test machine, after checking the signer matches the certificate, explicitly trust the *public test certificate* in the Local Machine Trusted People store (elevated PowerShell required):

    Import-Certificate -FilePath .\DKEasyRenamer-TEST-ONLY.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople

4. Run the signed probe installer. Do not use UNSIGNED-DO-NOT-INSTALL. Record SmartScreen/trust prompts without weakening global security.
5. Record the Windows build:

    Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber

## Generate disposable test files
From a checkout of the repository:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\New-TestFixtures.ps1

This creates a unique directory under %TEMP% with numeric filename samples, Unicode, spaces, two swap candidates and nested folders. It **never deletes or renames any existing files**. Record the printed directory path.

## Required interactive test matrix

| Case | Action on disposable fixtures | Expected outcome |
|---|---|---|
| 01 | Launch DK Easy Renamer | Branded app, icon, controls displayed |
| 02 | Right-click a single file in Explorer | Entry appears in Windows 11 *first-level* menu |
| 03 | Right-click several selected files, including Hangul/Japanese | Exactly selected paths are passed to one GUI |
| 04 | Right-click a folder | Folder itself is selected; children not separately renamed by default |
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
