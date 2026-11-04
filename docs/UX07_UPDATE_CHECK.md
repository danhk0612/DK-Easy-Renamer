# UX-07a — Manual update check and release notes

## Current behavior

- The **업데이트 확인** button is the sole trigger for the GitHub API request. There is no startup check, scheduler, background task, or resident process.
- Query the official `https://api.github.com/repos/danhk0612/DK-Easy-Renamer/releases/latest` endpoint, compare its stable three-part version with the installed application's assembly version, and ignore drafts, prereleases, malformed tags and untrusted release-page URLs.
- If a new stable version exists, show its version and a **plain-text preview of the official release body** (up to 600 characters); the full release notes remain available at the validated GitHub release-page URL. An absent release body is displayed as such.
- Opening the release page requires the user's confirmation. Markdown, URLs and note content are **not executed** or interpreted as installation commands.
- When there is no public stable release, report this explicitly. Test-only signed installers are not public update sources.
- The button does not download, execute or install any binary, and cannot modify Explorer registration or any file being renamed.

## Validation

- `StableReleaseParserTests`: newer/equal/older version comparison, rejected untrusted/unstable release URLs, parsed release body and missing/invalid body.
- `dotnet test DK-Easy-Renamer.sln -c Release` and Windows GitHub Actions build are the code gates.
- Windows 11 physical test: with a future legitimate public stable release, verify that the button shows the release notes and confirmation opens only the official page. No live release exists yet, so this display path cannot be verified end-to-end against production.

## Deferred UX-07b — Publicly trusted update installation

Do not automatically download or execute installers until the public signing method and certificate publisher identity are fixed and release assets can be independently verified. UX-07b in [issue #10](https://github.com/danhk0612/DK-Easy-Renamer/issues/10) requires SHA-256, Windows Authenticode chain and publisher verification, explicit approval, update lifecycle and rollback tests, and real Windows 11 upgrade/Explorer-menu acceptance. The persistent **development** certificate is test-only and must not be accepted as a public update signer.

No release, tag, or public installation is authorized by this document.
