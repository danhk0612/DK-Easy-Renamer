# Code signing policy — DK Easy Renamer

> **Status: application preparation only. SignPath Foundation has NOT approved this project, and no public release has been signed.** This is the project's proposed free GitHub Releases signing policy, not a claim of verified-publisher status.

## Proposed signing provider

If the project passes the [SignPath Foundation free OSS program](https://signpath.org/) review:

**Free code signing provided by [SignPath.io](https://signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).**

The Windows verified publisher will therefore be **SignPath Foundation**, not the developer's legal name or the product name. The developer controls the public repository and approves release requests; SignPath Foundation controls the signing certificate in its HSM.

No free certificate has been issued, no approval is assumed, and test self-signed packages must not be labeled as signed public distributions.

## Source and release provenance

- Official repository: https://github.com/danhk0612/DK-Easy-Renamer
- Official releases (none currently): https://github.com/danhk0612/DK-Easy-Renamer/releases
- License: MIT; third-party license register: [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md).
- Only binaries reproducibly built from this repository's approved version/tag on GitHub-hosted GitHub Actions runners may be submitted for signing. No user-provided executable is eligible.
- Proposed scope once validated by SignPath: published application EXE, native Explorer COM DLL, sparse MSIX and Inno Setup installer/uninstaller as required by the [public release plan](PUBLIC_GITHUB_RELEASE_PLAN.md). Each stage must use the actual same certificate publisher and align package identity.
- Each signing request requires a maintainer's explicit approval. The signing workflow will not silently sign arbitrary PRs, forks or test artifacts, and will not publish a GitHub Release without explicit authorization.

## Team and responsibilities

This is a single-maintainer project at present:

- **Authors / committers:** [danhk0612](https://github.com/danhk0612).
- **Reviewers:** [danhk0612](https://github.com/danhk0612), for code/build-script changes and all outside contributions.
- **Signing approver:** [danhk0612](https://github.com/danhk0612), subject to SignPath account approval and verification of the actual signer role.
- GitHub/SignPath MFA is a provider requirement. This policy is not evidence that MFA is already enabled; the developer must confirm before applying.

## Privacy and expected network use

DK Easy Renamer operates locally on user-selected files and folders. It does not run a resident agent, telemetry collection or an automatic update check. **Only when the user selects “업데이트 확인”**, the application requests the public GitHub Releases API; choosing to view a release opens the official GitHub page in a browser. These requests disclose the ordinary network metadata associated with reaching GitHub. Diagnostic logs and temporary update downloads are stored locally and are not automatically sent to the developer.

The application's current stored settings/Undo are session-local. This policy describes the present source code only; confirm dependencies and any changed network behavior before each public release.

## Security and maintenance

- Renaming requires a preview and explicit user confirmation; users can uninstall via Windows Installed Apps.
- The optional Windows 11 Explorer context menu must be selected intentionally during installation.
- App updates may not be downloaded/executed from arbitrary websites. The existing verified public installer update path remains intentionally disabled pending signed publisher approval.
- Existing self-signed development packages are not public releases and users must not be asked to install a test root certificate for public distribution.
- Release artifacts should include SHA-256 checksums, release notes, license notices and an explanation of how to verify the publisher and installation limitations.

The [SignPath Foundation Code of Conduct](https://signpath.org/terms.html) and its rules about project ownership, OSS dependencies, security, origin verification and manual approval must be satisfied before submitting a signing request.
