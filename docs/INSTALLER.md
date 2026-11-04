# T05 — Windows 11 installer and distribution (automated build)

## Packaging choice
- **Per-user Inno Setup 6 installer**, Windows 11 x64 only. Default destination: the current user's LocalAppData\Programs\DK Easy Renamer. No UAC required for ordinary use.
- **Self-contained .NET 10 win-x64 WPF application**, no separate .NET Desktop Runtime download required.
- **Native IExplorerCommand DLL** plus **Sparse MSIX** identity registered via Add-AppxPackage -ExternalLocation. Manifest logos, COM DLL, EXE and application icon remain beside the EXE.
- Installer copies the app and identity package, calls Register-Shell.ps1 as the same user, creates Start Menu shortcut, and calls Unregister-Shell.ps1 before uninstalling program files. Failure to register/remove raises an installer error; no silent false success.
- No tracking, network services or post-install app launch required.

## Signing and release boundary
A trusted certificate is a hard requirement for a functioning installed Explorer extension. It must match both the MSIX manifest Publisher and the EXE's embedded msix publisher.

Without a signing certificate, Build-Distribution.ps1 creates an **UNSIGNED-DO-NOT-INSTALL** installer candidate. It compiles and its files are inspectable, but its InitializeSetup deliberately blocks installation. For final Windows 11 testing, CI additionally generates a short-lived **non-exportable self-signed developer certificate** in its temporary runner store, signs a separately labeled **SIGNED-PROBE** installer, exports only the **public .cer**, and removes the private-key certificate from the runner. No private key or password is uploaded, and no automatic trust is granted on a user's PC.

Optionally provide -Publisher 'CN=<actual certificate Subject>' and -CertificateThumbprint '<cert in CurrentUser/My with private key>' to sign the external EXE, native DLL and MSIX. Inno Setup's SignTool directive signs the installer, uninstaller and Setup's temporary copies. The certificate must be trusted by the target Windows account. The signed output remains a **SIGNED-PROBE** pending real installation, trust-chain confirmation, removal/upgrade and SmartScreen reputation review. It prechecks the self-signed package certificate in LocalMachine TrustedPeople before writing any app files, and does not import certificates automatically. Do not publish to users from CI.

A temporary self-signed certificate is acceptable only on an isolated test machine with explicit trust. Public distribution requires a trusted signing solution; a new publisher may still trigger SmartScreen warnings until reputation is established.

## Automated Windows CI
The Windows GitHub Actions job performs:
1. Standard T00–T03 icon generation, WPF/Core tests and C++ COM build.
2. Install/find the Inno Setup 6 compiler, build the self-contained app with consistent identity metadata.
3. Package the identity-only MSIX; assemble installer and copy LICENSE and THIRD_PARTY_LICENSES.
4. Verify required files, parse PowerShell scripts, validate identity match and package ZIP, and check SHA-256 hashes.
5. Upload the clearly labeled unsigned/non-installable candidate separately.
6. Create a short-lived dev certificate, sign a separate **SIGNED-PROBE** setup and MSIX, validate signatures and identity, export its **public certificate** only, then remove the runner's signing key.

**Automated build evidence:** [Windows CI #30](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41597002092) succeeded: 19/19 Core tests, native COM x64, identity comparisons, both installer modes, and signing logs for the Inno uninstaller temporary image (`uninst.e32.tmp`) and final Setup executable. The uninstaller's *installed* signature is not yet confirmed. CI performs no installer execution, test-PC trust import or Explorer registration.

Run locally on Windows 11 with .NET 10 SDK, C++ Build Tools / Windows SDK and Inno Setup 6:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t03\Generate-Icon.ps1
    # Build C++ COM DLL as in docs/SHELL_INTEGRATION.md.
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t05\Build-Distribution.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t05\Validate-Distribution.ps1

Output: artifacts/t05/installer/DK-Easy-Renamer-0.1.1-x64-UNSIGNED-DO-NOT-INSTALL.exe, artifacts/t05/DKEasyRenamer.Shell.msix, SHA256SUMS.txt.

For a signed local test build, call Build-Distribution.ps1 with -Publisher matching the exact code-signing cert subject and -CertificateThumbprint, then explicitly trust the certificate on that test machine before installation. Alternatively, obtain the CI artifact **t05-DEV-SIGNED-TEST-ONLY-MANUAL-TRUST** containing the test-only signed installer and **DKEasyRenamer-TEST-ONLY.cer**. On an isolated test PC, inspect that public certificate, then *explicitly* import it into LocalMachine\TrustedPeople using elevated PowerShell before launching the signed installer; remove the certificate after testing. Never trust certificates from unverified sources or upload private keys/passwords.

## Mandatory T04 real-device acceptance
- On Windows 11 x64 ordinary user: signed probe setup installs without privilege elevation, exact package identity and first-level Explorer action appears.
- Files/folders/multiselection and Korean/UNC names are delivered to GUI. Rename/apply/undo and manual ordering work.
- Install path with spaces and Hangul, update of an older version, changed install directory and repeat installer behavior.
- Uninstall removes package and HKCU command values; no orphan Explorer menu; application files are removed without touching user files.
- App is correctly recognized in Windows Installed apps and Start Menu, has the right icon, and light/dark UI remains usable.
- Signing trust, binary/publisher alignment, installer/uninstaller signature chain and SmartScreen behavior verified.
- Reject unsigned candidate installer; verify hashes; verify user data not removed.

If any real-world test fails, repair it in T04 before publishing. T05 is not release approval.

## References (checked 2026-11-03)
- Microsoft: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
- Microsoft: https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windows-11
- Inno: https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm
- Inno: https://jrsoftware.org/ishelp/topic_scriptevents.htm

## Confirmed installation issue (2026-11-03)

A Windows 11 tester reported `0x800B0109` from `Get-AppxLog`: MSIX self-signed certificate untrusted. Earlier builds copied EXE files before attempting shell registration. Updated signed builds call `Preflight-Shell.ps1` from Inno Setup `PrepareToInstall` and stop without copying files when machine-level certificate trust is missing. The test `.cer` must come from the same signed-probe build. In an isolated test machine, **inspect the certificate and approve its trust** using elevated PowerShell:

    Import-Certificate -FilePath .\DKEasyRenamer-TEST-ONLY.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople

After testing, remove only that certificate's exact thumbprint from the same LocalMachine store. The installer never changes the certificate store itself. Other registration failures still require AppxLog review.


## Stable development signing for repeatable T04 installers (preferred)

Automatic pull-request CI still generates a disposable development certificate for signing-path verification; its public .cer changes each run. For repeated Windows 11 installation tests use the separate manual stable-dev-sign job in the Windows CI workflow. It reuses one certificate.

### One-time certificate creation (trusted Windows PC)

From a local checkout of the T04 branch, choose a PRIVATE directory outside the Git repository:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t05\New-StableDevCertificate.ps1 -OutputDirectory "$env:USERPROFILE\Documents\DK-Renamer-Private"

Enter a strong PFX password and store it securely. This creates:
- DKEasyRenamer-STABLE-DEV.pfx — PRIVATE signing key. Never commit, attach, send in chat or distribute.
- DKEasyRenamer-STABLE-DEV.cer — public-only test certificate.
- A public SHA-1 certificate thumbprint (40 hex characters), printed by the generator.

Keep the same PFX for repeated development builds; do not regenerate it per CI run.

### One-time GitHub environment configuration

In GitHub Settings > Environments, create an environment named dev-signing. Require approval for access to its secrets where supported and restrict permitted branches. Review the selected branch before approving a signing run.

With GitHub CLI installed and authenticated, register the PFX as a secret without printing it to the console:

    $repo = 'danhk0612/DK-Easy-Renamer'
    $pfx = "$env:USERPROFILE\Documents\DK-Renamer-Private\DKEasyRenamer-STABLE-DEV.pfx"
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfx)) | gh secret set DK_DEV_SIGNING_PFX_BASE64 --env dev-signing -R $repo

Enter the SAME PFX password using the interactive CLI prompt:

    gh secret set DK_DEV_SIGNING_PFX_PASSWORD --env dev-signing -R $repo

Set the publicly known thumbprint as an environment variable (replace FINGERPRINT with the generator's exact 40 characters):

    gh variable set DK_DEV_SIGNING_THUMBPRINT --body 'FINGERPRINT' --env dev-signing -R $repo

After reviewing the branch, run the existing registered Windows build workflow manually:

    gh workflow run ci.yml --ref work/t04-windows-acceptance -f stable_dev_signing=true -R $repo

If required, approve the protected dev-signing environment job. Only this manually triggered job can read the environment secrets; ordinary pull-request CI cannot. It validates the expected subject, private key, pinned thumbprint and expiry, removes the temporary PFX and imported signing certificate from the runner, and uploads the separate artifact t05-STABLE-DEV-SIGNED-TEST-ONLY. The artifact includes the signed test installer, MSIX, SHA256 checksums and PUBLIC certificate. No PFX/private key or password is uploaded.

### Windows 11 trust and repeat tests

Verify installer origin/signature and public certificate match first. On an isolated Windows 11 test device only, a user may explicitly trust the public certificate in an elevated PowerShell:

    Import-Certificate -FilePath .\DKEasyRenamer-STABLE-DEV.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople

Future builds signed with the SAME pinned key do not require repeating that trust step. The native DLL still needs an Explorer refresh/restart after updates. When finished testing, remove only this certificate's exact thumbprint from the machine store. Never automatically trust a new key, and never use this self-signed test identity for public release.

If dev-signing secrets are not configured, the stable signing job fails safely; code changes alone cannot create or upload a private credential.

References:
- https://docs.github.com/en/actions/concepts/security/secrets
- https://cli.github.com/manual/gh_secret_set
- https://cli.github.com/manual/gh_variable_set
- https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide

## Branding for package identity (T04)

Unlike the WPF window icon, the Windows taskbar uses the `Square44x44Logo.png` declared in `AppxManifest.xml` after sparse package registration. The builder now resizes the original 256px document/pencil PNG to all three MSIX visual logos, removing the previous `DK` text placeholder. The WPF window inherits the original ICO through the ApplicationIcon build setting. The 0.1.1 test version prevents mixing new assets with the old 0.1.0 package identity. After updating, restart Explorer/sign out if taskbar pinning caches the old glyph; remove/re-pin an old shortcut only when needed.
