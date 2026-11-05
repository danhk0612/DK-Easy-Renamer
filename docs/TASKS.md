# Tasks — sequential delivery baseline

Updated 2026-11-05: T00–T03 and T05 are merged. T04 implementation was merged; user-observed Windows 11 interactive acceptance remains open in issue #7. UX-07 development continues through merged PR #27, but the public signer, Release and real-device migration/rollback gates remain open.

| Stage | Status |
|---|---|
| T00 foundation | Merged and CI pass |
| T01 Explorer integration | Merged; actual Windows 11 file/folder context menu confirmed after reboot |
| T02 rename core | Merged; disposable filesystem tests pass |
| T03 Fluent GUI | Merged; compile pass; actual apply/Undo, sorting and theme require testing |
| T05 installer | Merged; Windows 11 signed test install confirmed; Windows Server 2025 install/uninstall CI passed; Windows 11 upgrade/uninstall unverified |
| T04 integrated acceptance | Code tested on CI and Windows Server 2025; Windows 11 interactive UI acceptance pending in issue #7 |

## Reusable test certificate
- tools/t05/New-StableDevCertificate.ps1 creates a one-time PRIVATE PFX OUTSIDE the repo.
- workflow_dispatch with stable_dev_signing=true runs a separate job in the protected dev-signing environment, with two secret inputs and a pinned public thumbprint variable.
- The GitHub environment has not yet been provisioned with a persistent private key. Ordinary CI may continue to generate short-lived certificates but its artifacts are not intended for repeated end-user installation tests.
- No private key, password or encoded key is committed or uploaded in any build artifact.

## Gate
The T04 code was merged after its automated checks. Windows 11 interactive acceptance is tracked separately in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7), and remains INCOMPLETE until explicit user observations. No public Release/tag until that checklist passes and a suitable release-signing method is available.

## Latest automated evidence

[CI #41753265249](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41753265249) passed 21/21 tests, WPF/native builds, 0.1.1 branded MSIX packaging, actual Windows Server 2025 signed install, application window title inspection and uninstall cleanup. This does not establish Windows 11 taskbar/caption visual acceptance.

## UX-07 progress (2026-11-05)

| Work | State |
|---|---|
| UX-07a manual stable Release check | Merged; user-initiated only |
| UX-07b guarded download and installer handoff | Merged through #22; actual public install blocked pending public signing identity |
| UX-07c/d conflicting publisher and owner guards | Merged #23–#24; no automatic cross-publisher removal |
| UX-07e read-only migration diagnostics | Merged #25; never authorizes migration |
| UX-07f local-data snapshot rehearsal | Merged #26; new-directory restore rehearsal only |
| UX-07g signed old installer/MSIX archive rehearsal | Merged #27; no live rollback |
| T04/UX-07 final Windows 11 approval | Open issues #7 and #10 |

Do not equate Windows Server 2025 CI signatures, ephemeral test trust, or a backed-up installer with approval for an actual Windows 11 public publisher migration. A future implementation must be independently scoped, preserve verified rollback materials, explicitly obtain user approval, and test both successful and failed transitions on a disposable Windows 11 machine. The current release/tag prohibition remains.
