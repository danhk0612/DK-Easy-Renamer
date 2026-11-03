# T01 — Windows 11 Modern Context Menu Integration Contract

## Goal
After installation/registration on **Windows 11 x64**, a `DK Easy Renamer` action appears in the **first-level** Explorer context menu for selected files and folders, including multiselection. Clicking it launches/activates the app with the exact selection and does not rename any file.

## Proposed mechanism
- Native x64 COM DLL implements `IExplorerCommand`.
- Register with Windows app package identity via `windows.comServer` and `windows.fileExplorerContextMenus` in the package manifest.
- For an unpackaged WPF executable investigate a *sparse MSIX* package (`uap10:AllowExternalContent`) for identity, and ensure native DLL can be activated as packaged.
- Keep Explorer in-process code minimal. If selection handoff uses IPC, design bounded timeouts and verify Unicode/multiple paths.
- Verify packaging/install/uninstall, certificate trust and operation from ordinary (non-admin) user accounts; test real Explorer behavior.
- No fallback to *only* the legacy "Show more options" menu without explicit acceptance.

## Required T01 evidence
1. A Windows 11 build/version and architecture, reproducible commands and executable artifacts.
2. Screenshots/logs of the first-level Explorer item for one/multiple files and folders, with exact Unicode paths arriving in the app.
3. Installation and clean removal of registrations; repeatability, non-admin launch, and after-Explorer-restart behavior.
4. Dev certificate vs production signing/distribution limits explicitly documented.
5. CI compile and environment-dependent test limits honestly reported.

## Source
https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer

**Current state:** Unimplemented. T00 contains only this design contract.
