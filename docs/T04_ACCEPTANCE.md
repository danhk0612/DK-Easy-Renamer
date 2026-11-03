# T04 — Windows 11 final acceptance: NOT YET EXECUTED

The T00–T05 code builds. CI runs on Windows Server and cannot prove the Windows 11 Explorer first-level context menu or WPF interactions actually work. Only actual Windows 11 x64 test evidence can close T04.

## Safety
Use a dedicated Windows 11 test account or disposable VM. Never perform test renames on personal files or production network shares. T04 test scripts do not touch existing user files.

## Test-only installer preparation
1. Download the artifact **t05-DEV-SIGNED-TEST-ONLY-MANUAL-TRUST** from the latest passing Windows CI of this repository. It includes DK-Easy-Renamer-0.1.0-x64-SIGNED-PROBE.exe, a public test certificate DKEasyRenamer-TEST-ONLY.cer, and SHA256SUMS.txt.
2. Check the SHA-256 hash, verify the file origin and compare the thumbprints:

    Get-AuthenticodeSignature .\DK-Easy-Renamer-0.1.0-x64-SIGNED-PROBE.exe | Format-List Status,SignerCertificate
    Get-PfxCertificate .\DKEasyRenamer-TEST-ONLY.cer | Format-List Subject,Thumbprint,NotAfter

3. Only on an isolated test account, and only after checking the certificate and installer match, explicitly trust the *public test certificate* for that account:

    Import-Certificate -FilePath .\DKEasyRenamer-TEST-ONLY.cer -CertStoreLocation Cert:\CurrentUser\TrustedPeople

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
    Remove-Item -LiteralPath ("Cert:\CurrentUser\TrustedPeople\" + $testCert.Thumbprint)

Do not remove unrelated certificates. The disposable test fixture remains until intentionally deleted.

## Evidence and exit gate

For each case record PASS, FAIL, or BLOCKED; Windows build, artifact ID and hash, certificate thumbprint, screenshots, error text and reproduction steps. Real device tests not run = **T04 BLOCKED**, not a pass. Production Release/tag remains prohibited pending complete acceptance and an appropriate public signing solution.
