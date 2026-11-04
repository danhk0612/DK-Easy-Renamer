# UX-07b (part 1): Public installer verification preflight

## Current stage — intentionally not an installer

This task adds **offline verification components** while the public publisher's certificate and package-identity migration are still undecided. No button, download, process launch, release or tag is added.

### 1. GitHub release asset metadata

`OfficialInstallerAssetVerifier.Find(releaseJson, expectedFileName)` requires:

- Official stable release and an explicit filename supplied by a future approved release policy; the filename's version must match the release.
- A uniquely named uploaded `.exe` asset from `https://github.com/danhk0612/DK-Easy-Renamer/releases/download/<tag>/<filename>`.
- GitHub Releases API `digest = sha256:<64 hex>` and positive asset size.
- No query/user-info/fragment/alternate host, no test/development/unsigned/probe build.

`VerifySha256` checks complete downloaded bytes, but **a matching digest is not proof of a trusted publisher**, because it comes from the same release metadata. Authenticode remains mandatory.

### 2. Offline Windows signature validation

`tools/ux07/Validate-PublicInstaller.ps1` requires **all** of:

1. The approved SHA-256 hash matches the local file.
2. Windows `Get-AuthenticodeSignature` returns `Status = Valid` with a signer certificate.
3. Certificate subject **and exact certificate thumbprint** match a separately approved public release identity.
4. Reject the current `CN=DK Easy Renamer Development` identity and self-issued signing certificates.

The script never downloads, imports a trust anchor, changes files, starts an installer, or installs anything. Approval of a public signing certificate must precede any use with real releases. Signing certificate rotation requires an explicit policy update and review.

### CI and limitations

Windows CI performs .NET build, unit tests including release-asset filtering and SHA-256 mismatch cases, and a PowerShell syntax/negative test proving an unsigned fixture and the development publisher are rejected.

**Not yet verified:** a real publicly signed positive example; live official release download redirect behavior; download-to-staging and tamper-safe launch; user confirmation and Undo state; upgrade/rollback and Windows 11 shell registration. These are blocked from production by design until public signing and Windows 11 acceptance are complete.

### Packaging identity blocker

The current 0.1.2 test package uses `CN=DK Easy Renamer Development` as the Sparse MSIX publisher. Choosing a different **public** publisher changes its package identity/family name. Public release planning must explicitly cover the upgrade or migration from existing test installations, including old Explorer COM registrations and user data; it must not silently rewrite publisher metadata or claim an in-place upgrade works.

### Release activation contract

Before enabling download/install in UX-07b, decide and verify:

- Publicly trusted Windows code-signing provider, certificate subject and fingerprint (never store private key in the repository), publisher identity across EXE/DLL/MSIX/Setup and the final canonical public asset filename.
- Approved GitHub Release upload path, asset digest and stable version contract.
- Exact hash, Windows trust-chain and publisher checks **again immediately before execution**; no arbitrary commands, executables or download URLs.
- User confirmation, cancel behavior, running-app exit, pending Undo warning, installer return code, same installation path, restart, Explorer shell registration and rollback tests.
- End-to-end Windows 11 upgrade, downgrade rejection, uninstall, and test certificate migration.

Until those are met, the UI remains the UX-07a release-notes viewer with a link to the official release page. Development signed builds are strictly test-only.

References:
- GitHub: https://docs.github.com/en/rest/releases/assets
- Microsoft: https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-authenticodesignature
- Existing tracker: https://github.com/danhk0612/DK-Easy-Renamer/issues/10

## Build -> certificate -> signing -> upgrade test (CI verification)

The development path now tests the practical order without obtaining or pretending to obtain a publicly trusted certificate:

1. Build and test the .NET/WPF app, Core, native Explorer COM DLL and unsigned identity/installer.
2. On the isolated `windows-2022` runner, generate a **temporary, non-exportable self-signed development certificate** after the unsigned build.
3. Sign both the existing **0.1.2** and a **CI-only 0.1.3** installer/MSIX with that same temporary certificate. The second version uses `-Version 0.1.3` only for the test build. Restore the original 0.1.2 standard artifact after capturing both fixtures.
4. Publish the two disposable signed versions plus the **public** .cer as a 7-day GitHub Actions artifact named `t05-SIGNED-UPGRADE-TEST-ONLY`. Never publish a Release/tag; never upload a private key.
5. In a fresh `windows-2025` CI runner, explicitly trust the public .cer **only on that ephemeral test VM**, install 0.1.2, verify package identity and shell registration, create local user data, upgrade to 0.1.3, confirm single new package version and unchanged install path/data, then uninstall and confirm registration cleanup.
6. Remove the temporary test trust and fixture data. Report this as **Windows Server 2025 CI evidence**, not Windows 11 Explorer GUI acceptance or publicly trusted publisher validation.

The disposable 0.1.3 version is NOT a formal release, and must never become the application version without a separate version decision.

A public signing certificate is issued by an approved signing provider **after identity verification**, and is *not* produced by building binaries or generating the disposable test certificate. Public signing and user-facing automatic installation remain gated as described above.

Existing signed installer smoke coverage is retained separately. Any failed upgrade assertion blocks the PR and must not be reported as successful.
