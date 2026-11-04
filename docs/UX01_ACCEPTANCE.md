# UX-01: Windows 11 test build 0.1.2 physical acceptance

## Scope and safety

The original first-level DK Easy Renamer로 이름 변경 menu must continue to launch the full editor with no extra click. The new DK Easy Renamer 빠른 작업 submenu contains:
- 빠른 순번 변경... -> existing editor with sequence rule preselected
- 빠른 찾기·바꾸기... -> existing editor with find/replace rule preselected

This is a first implementation, not a separate compact dialog. The selected paths use the existing DKR1 Unicode packet and the new mode has a strict allowlist. No Explorer COM callback renames files; WPF quick mode never applies without confirmation.

This 0.1.2 test package retains the existing package name/publisher and original installed command CLSID. A version increment is necessary to ensure the changed shell manifest can be upgraded from 0.1.1.

## Fixed-signature test package (after main CI success)

Use the existing protected GitHub dev-signing environment and stable certificate. Never regenerate PFX or place a private key/password in the repository, chat or artifacts. From the cloned repository:

    git pull --ff-only
    gh workflow run ci.yml --ref main -f stable_dev_signing=true -R danhk0612/DK-Easy-Renamer

Download the new workflow artifact named t05-STABLE-DEV-SIGNED-TEST-ONLY; confirm that the signed installer and CER use the pinned development certificate thumbprint CBA4EBCBF8EE449F59B53D4F668A8849671B56D3 before installing on the authorized test PC. Do not install a PR artifact with a freshly generated test signing key.

## Windows 11 acceptance (pending user observation)

- [ ] Existing single-click file/folder menu entry remains available.
- [ ] New quick group and both Korean-titled child commands appear and launch the one correct WPF editor.
- [ ] Sequence mode preselects the rule and previews 001_file1.txt for disposable file1.txt; Replace mode preselects the proper rule and waits for user input.
- [ ] Preview/Apply/Undo on disposable fixtures restores original names and bytes. Nothing changes before user confirmation.
- [ ] Group layout and number of clicks are acceptable; no slowdowns or Explorer crashes with 1 and 20 selections.
- [ ] App checks GitHub only when the explicit update button is clicked; before any public stable release, it reports no public update.
- [ ] Windows registered package identity is 0.1.2.0; uninstall removes menu and keeps user data.
- [ ] Previous issue #7 icon/title/theme/DPI checks are still required.

CI Windows Server and compile checks are separate from physical Windows 11 Explorer menu acceptance. No public Release/tag until approval and public signing.
