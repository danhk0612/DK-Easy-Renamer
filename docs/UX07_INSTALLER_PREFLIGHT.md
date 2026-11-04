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
