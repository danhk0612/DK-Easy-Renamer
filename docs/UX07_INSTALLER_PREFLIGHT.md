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

## UX-07b (part 2): hash-verified download staging

`src/DK.EasyRenamer.Core/VerifiedInstallerDownloader.cs` adds an isolated, **non-executing** download stage. It consumes an `OfficialInstallerAsset` previously selected by `OfficialInstallerAssetVerifier.Find` from the official stable GitHub Releases API.

- Caller-supplied `HttpClient` **must** disable automatic redirects (`AllowAutoRedirect = false`). The downloader inspects up to 5 redirects and accepts only HTTPS, default port, no user-info/fragment, and GitHub's `release-assets.githubusercontent.com` or `objects.githubusercontent.com` asset hosts. It rejects arbitrary external destinations and unexpected HTTP redirect handling.
- Incoming asset name, URL, digest and positive size are checked before network/disk I/O. The maximum accepted installer size is 512 MiB.
- Response size, streamed byte count and SHA-256 digest are compared against the official asset record. Incomplete, oversized or tampered downloads are rejected.
- Each attempt writes to a newly generated subfolder as `download.part`; only after verification is it renamed to the expected installer filename. On any error or cancellation, that attempt's temporary folder is deleted; previously downloaded files are untouched.
- `VerifiedInstallerDownloaderTests` use only disposable fake bytes and in-memory HTTP handlers. No real installer is downloaded or executed in tests.

### Still required before an app-facing install button

`VerifySha256` is **not a code-signing substitute**: the official GitHub API returns both the asset and digest. The downloaded file must still pass the existing public Authenticode/trusted publisher preflight, and should be rechecked immediately before any process execution. The repository has no approved public signer and no official stable release. Consequently, this stage has no WPF button, automatic installer launch, release or tag.

The ability to install the WPF app without a trusted MSIX certificate (PR #18) concerns optional Explorer shell registration only. It does **not** authorize running an unsigned downloaded executable automatically.

## UX-07b (part 3): in-app signed installer handoff (disabled until public approval)

A manual click on **업데이트 확인** is the only trigger. When a newer official stable release is published, the app presents its notes. Two possible outcomes are intentionally different:

- **Current build (no approved public publisher):** `PublicUpdatePolicy.TryGetApprovedPublisher` returns false; the user can choose to open the official release webpage. No installer download or execution occurs. Existing development/self-signed signing certificates and unsigned APP-ONLY packages **cannot** activate this flow.
- **After a future reviewed public publisher identity is compiled into `PublicUpdatePolicy`:** only an exact `DK-Easy-Renamer-X.Y.Z-x64-RELEASE.exe` asset from a newer official stable release qualifies. The user explicitly chooses download; the existing `VerifiedInstallerDownloader` checks redirect/size/SHA-256 before exposing the staged file.

For a qualifying downloaded installer:

1. The WPF application invokes its **packaged** `Validate-PublicInstaller.ps1` with a pinned subject and exact thumbprint. The PowerShell script requires a valid Windows Authenticode signature and checks the downloaded bytes against the official asset's SHA-256. It never imports certificates.
2. It inspects the current-user Explorer shell registration. Status `0` means keep the optional shell menu; statuses `1` and `2` mean keep it unregistered. Unknown or conflicting status blocks installer handoff instead of silently removing existing context-menu registration.
3. A separate warning explicitly describes session-only Undo/unsaved UI state and asks for **final approval**.
4. The *same SHA-256 and public publisher signature checks* run again just before process launch. Only after approval and verification is Inno Setup started, with `/TASKS=shellmenu` for an already registered menu or `/TASKS=` for an app-only installation. Inno manages app close/update lifecycle.
5. If the user declines or verification fails, the newly downloaded staging directory is removed on a best-effort basis. A directory handed to a running installer is left intact because deleting it while Setup runs would break the update. Staged-file post-install cleanup is **not yet automatic**.

### Unresolved production and Windows 11 gates

- A public signing certificate and its reviewed subject/thumbprint have **not been chosen**, and the project's GitHub repository has no published official stable release. Accordingly, no live in-app download, valid-public-signer positive test or real installer execution was possible.
- A newly approved MSIX Publisher might change sparse identity; a migration policy for existing developer-signed Explorer registrations must be tested on real Windows 11 machines **before** the policy constants may be populated.
- Windows 11 GUI consent, installation return codes, reopen/rollback behavior, app data preservation, and safe cleanup after installation remain acceptance work. CI build/tests and previous Windows Server upgrade smoke **do not** establish full public release readiness.
- Do not enable installer launch by substituting test signer values, trusting a self-signed certificate automatically, or allowing unsigned executables.

This is a guarded install workflow, **not** a usable public automatic updater until those gates are explicitly completed.

## UX-07b (part 4): one-shot installer process and post-success staging cleanup

The app-side user confirmation and public publisher gate remain unchanged. On final approval the app now hands the downloaded installer to the packaged `Invoke-VerifiedUpdate.ps1` one-shot process instead of launching Inno Setup directly.

- This external PowerShell process survives Inno Setup closing/replacing the WPF application. It repeats the **same** SHA-256, trusted Authenticode and pinned public publisher verification immediately before invoking Setup.
- The one-shot process launches Setup with the existing shell-selection parameter (`/TASKS=shellmenu` or `/TASKS=`) and waits for the installer process tree to finish. It does not poll the network, run at system startup, auto-elevate, create scheduled tasks, or import any certificate.
- After a **zero exit code** and verification that the installed file has not changed into a symlink or different digest, it deletes **only that exact downloaded .exe**. It removes the unique 32-hex staging directory only if empty; it never recursively deletes anything from the user's Downloads, documents, arbitrary paths or unrelated update folders.
- Before any launch, the helper allows only `%LOCALAPPDATA%\DK Easy Renamer\Updates\<32-lowercase-hex>\DK-Easy-Renamer-X.Y.Z-x64-RELEASE.exe` and rejects a reparse point at the app data directory, update root, attempt directory or installer. It does **not** accept development probes/APP-ONLY files.
- Canceled/failed installations, interrupted helpers and unexpected file modifications may leave the staged file behind. No recurring cleanup service is installed. A future explicit retention or retry policy must not silently delete these files.
- The dedicated Windows CI stage-path smoke uses fake bytes and `-CheckStagingPathOnly` (no signature verification, launch or removal) to assert invalid/outside paths are rejected; packaging checks ensure the one-shot helper is included. Existing installation and upgrade CI smoke remain unchanged.

This is **not** an end-to-end public installer test: no publicly signed release exists and this process/handoff cannot yet be exercised with a real approved publisher. Test the helper's real Setup process-tree wait and post-success cleanup on a disposable Windows 11 VM with an approved release before declaring public updater readiness. In-app update execution remains disabled by the empty `PublicUpdatePolicy` identity.

## UX-07b (part 5): isolated signed-fixture execution regression

`tools/ux07/Test-VerifiedUpdateExecution.ps1` is a CI-only test. It refuses to run outside a disposable Windows GitHub Actions runner. After .NET 10 is set up, it compiles a harmless console program that only records its received installer arguments and exits with a controllable code. On the runner alone, the test creates a one-day private **CI test CA** and a CA-issued temporary code-signing leaf, explicitly trusts the root in the disposable CI runner's LocalMachine Root store (administrator-only, avoiding CurrentUser interactive consent), then signs that fixture executable. The private key/PFX is never exported or uploaded, and the test removes the temporary test trust when done.

Without changing or bypassing the product's `Validate-PublicInstaller.ps1` or the unconfigured `PublicUpdatePolicy`, the test passes the fixture through the **real** `Invoke-VerifiedUpdate.ps1`:

1. Test fixture exits zero with `/TASKS=`: download staging file and empty GUID folder are deleted.
2. Test fixture exits zero with `/TASKS=shellmenu`: the original optional Explorer preference is forwarded and staging cleaned.
3. Test fixture exits nonzero: runner reports failure and leaves this stage intact.
4. Incorrect expected SHA-256: fixture never runs and downloaded bytes are preserved.
5. Successful fixture with unrelated sentinel file in its GUID folder: only the installer EXE is deleted; sentinel and folder remain.

These are **test certificates**, not certificates to deploy to users, and this verifies handoff/cleanup logic rather than a publicly trusted CA or real Inno Setup upgrade. In particular the test never fills in the public publisher policy and never publishes a GitHub Release. Real Windows 11 interactive acceptance remains a separate gate.

### Current signing-service eligibility (verified 2026-11)

Microsoft's Artifact Signing quickstart presently lists **South Korea for organization Public Trust**, while **individual Public Trust** requires USA or Canada. Microsoft Store individual developer registration is available free of charge through the new Store onboarding, with Store-signed MSIX packages, but switching this existing Inno Setup + sparse MSIX Explorer integration to Store distribution would require a separate packaging and identity migration project; it is not a direct substitute for signing the existing EXE distribution. Standard CA code-signing is an external option, subject to the CA's applicant identity requirements, fees, issuer changes and renewal/rotation. The current policy pins one exact public leaf certificate thumbprint; if the chosen signer rotates its leaf certificates, a vetted rotation policy must be implemented **before** activation.

Authoritative references:
- https://learn.microsoft.com/en-gb/azure/artifact-signing/quickstart
- https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
- https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer
- https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide

**No public signing provider is selected by this test, no certificate enrollment is performed, and user-facing install remains fail-closed.**

## UX-07c: refuse silent publisher-family replacement before installation

Windows MSIX package family identity includes **Name and Publisher**. A different public signing subject changes the package family; Windows cannot treat it as an ordinary same-family upgrade. This stage deliberately does **not** choose a new public publisher or perform a migration.

- `installer/windows/Test-ShellPublisherTransition.ps1` reads the incoming MSIX's `AppxManifest.xml` directly from its ZIP container, requires exact package name `DKEasyRenamer.Shell`, and compares its `Identity Publisher` with any existing current-user `Get-AppxPackage -Name DKEasyRenamer.Shell` registration.
- **No registration** or **same exact Publisher** is allowed to proceed to the existing certificate/registration gates. Missing, malformed, ambiguous or different publisher records **fail closed**.
- Inno's optional-menu preflight extracts and invokes the new guard **before app files are overwritten**, including silent `/TASKS=shellmenu` requests. If publisher identity differs, the opt-in menu cannot be applied. The base app's unrelated APP-ONLY installation remains available when no menu opt-in is chosen.
- `Register-Shell.ps1` invokes the same guard again **before Remove-AppxPackage**. It will not destroy the old Explorer menu identity merely to attempt registration with a new publisher.
- `Query-ShellState.ps1` checks for an installed package whose publisher differs from the current installed MSIX; a conflict is reported as state **3**, which disables the in-app menu toggle and update handoff instead of misreporting the menu as owned.
- `tools/t04/Smoke-PublisherTransition.ps1` runs **only** in disposable Windows CI. It generates fake ZIP/MSIX manifests and mocks `Get-AppxPackage`, signature and removal commands. The test checks fresh/same-publisher acceptance; old-development-to-new-public-publisher rejection after the existing signer preflight but before any application file changes; no `Remove-AppxPackage` call on mismatch; and malformed/ambiguous registration refusal. **No actual package registration, trust-store changes or user-file mutation occurs in this test.**

This guard is an intentionally conservative **block**, **not** a publisher migration mechanism. Moving from the current development signer to a chosen public CA requires a separately approved, Windows 11 tested workflow that preserves app data, explicitly removes only the user's matching old package, registers the new identity, verifies Explorer integration and handles failure/rollback. The existing same-publisher CI upgrade does not prove that migration.

Microsoft documentation:
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/package-identity-overview
- https://learn.microsoft.com/en-us/windows/msix/app-package-updates
- https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide

**Release/auto-update remain blocked** until a public signing identity is approved, with no GitHub Release or tag generated by this change.

## UX-07d: owner-confirmed Explorer unregistration, no automatic migration

Removing a package by `Get-AppxPackage -Name DKEasyRenamer.Shell` alone does **not** prove that the caller owns its registration. A different publisher can produce a distinct MSIX package family despite having the same package name. This stage changes only the existing `Unregister-Shell.ps1` command used by opt-out/uninstall/in-app menu removal:

- Collect the current user's registered package(s) and `HKCU:\Software\DKEasyRenamer\ExecutablePath` **before mutation**. More than one package, a foreign path, or an incomplete owner record blocks removal. If a package exists but no owner registry record exists, preserve the package rather than guessing ownership.
- For a single owned package, require the installed `DKEasyRenamer.Shell.msix` and bundled `Test-ShellPublisherTransition.ps1` to exist, and verify that the installed manifest publisher matches the registered package's publisher. **Do not remove a package from another publisher/family.**
- After `Remove-AppxPackage`, query again and delete the current user's matching owner record only when the registered package is actually absent. On an error/incomplete package removal, retain the owner record for manual diagnosis.
- If no package remains, clean up an owner record **only if its executable path matches the current installation**; if neither exists, this is a harmless no-op.
- Does not import/export certificates, remove app files or user data, manipulate other users' packages, install a new identity, or make an automatic migration decision.

`tools/t04/Smoke-OwnedShellUnregister.ps1` runs on a disposable Windows GitHub Actions runner only. It uses a temporary fake MSIX manifest, mocked `Get-AppxPackage`/`Remove-AppxPackage` calls and an isolated test-only HKCU record. It verifies unknown owner, foreign path, publisher mismatch, duplicate registration, missing MSIX, failed/incomplete removal, successful owned removal and stale owned-record cleanup. **The test never removes an actual MSIX package or any production installation.**

### Remaining publisher migration and rollback gate

No publicly trusted signer has been approved, so a cross-publisher migration remains blocked. A future, separately approved migration must first establish verified backup/restore artifacts for the old and new package identities, installed binaries, file paths and user settings, then test failure recovery on Windows 11. This change only makes the **existing removal path fail closed** until those conditions are satisfied.

## UX-07e: read-only migration readiness report (no state changes)

The next preparatory stage is documented in
[UX07_PUBLISHER_MIGRATION_READINESS.md](UX07_PUBLISHER_MIGRATION_READINESS.md).

The new command reads the current user's owned Explorer registration, the old
MSIX package identity and checksum, and the proposed new MSIX identity and
signer metadata. It emits a JSON classification and identifies recovery inputs
still missing. It has **no apply or rollback mode**: no current-user package,
registry key, certificate, user data or installation is changed. The report
never constitutes public-signing approval.

CI runs an isolated fake-package/owner-state matrix with Appx mutations
explicitly prohibited. Real cross-publisher migration and rollback on Windows
11 remain blocked until a public signing and distribution policy is approved.
