# Tasks — sequential delivery baseline

Updated 2026-11-04: T00–T03 and T05 are merged. T04 additionally corrects packaged taskbar logos and native caption and builds a distinct 0.1.1 test package. T04 is open as PR #6 with partial Windows 11 acceptance evidence. The reusable development signing workflow is implemented in this PR but cannot issue an artifact with a fixed certificate until a developer provisions its PFX and protected GitHub environment values.

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
PR #6 contains the T04 code and automated checks and may merge after CI passes. Windows 11 interactive acceptance is tracked separately in [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7), and remains INCOMPLETE until explicit user observations. No public Release/tag until that checklist passes and a suitable release-signing method is available.

## Latest automated evidence

[CI #41753265249](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41753265249) passed 21/21 tests, WPF/native builds, 0.1.1 branded MSIX packaging, actual Windows Server 2025 signed install, application window title inspection and uninstall cleanup. This does not establish Windows 11 taskbar/caption visual acceptance.
