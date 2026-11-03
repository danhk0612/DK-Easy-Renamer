# Tasks — sequential delivery baseline

**2026-11-03:** T00–T03 merged. T05 installer merged via PR #5; [CI #31](https://github.com/danhk0612/DK-Easy-Renamer/actions/runs/41597518140) passed 19/19 core tests, WPF/C++ builds, unsigned and short-lived developer-signed setup/MSIX, Inno uninstaller signing, identity and hash checks. All actual Windows 11 Explorer/UI/install behavior remains unverified. The user requested maximum development before physical tests.

| Task | Status |
|---|---|
| T00 foundation | Merged, CI pass |
| T01 native Windows 11 Explorer extension | Merged; actual menu not tested |
| T02 renaming engine and undo | Merged, 19/19 disposable filesystem tests |
| T03 Fluent GUI and branding | Merged, CI build; real UI not tested |
| T05 installer, package signing | Merged, CI builds; real install/uninstall not tested |
| **T04 final integrated Windows 11 acceptance** | **BLOCKED until real Windows 11 tests**, see docs/T04_ACCEPTANCE.md |

T04 cannot be marked complete, merged as accepted, or used for production Release without actual Windows 11 screenshots/logs and passing user workflows. Use only disposable fixtures for rename tests. No release/tag without explicit authorization.
