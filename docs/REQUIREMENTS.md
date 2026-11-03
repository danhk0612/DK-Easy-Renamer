# Requirements v1.0 (2026-11-03)

## Scope
- Windows 11 x64 desktop application `DK Easy Renamer`, MIT license.
- Launch from the modern first-level File Explorer context menu for one or more selected files/folders.
- Manual launch, in-app add, and drag/drop selection; explicit choices for renaming selected folders themselves or contained entries.
- Explicitly show original name, proposed name, path, and validation status before applying.
- Sort by name (including natural numeric ordering), creation/modification time, and size (asc/desc); move one or multiple rows manually. Order remains stable when rename rules change.
- Support GUI rules: find/replace, add/remove prefix/suffix, sequential numbering (start, increment, width, separator, position), delete substring, trim N characters, case, extension editing, creation/modification date insertion and substring position/length.
- Combine rules in a user-controlled order; each rule is independently enabled/disabled. Optional advanced regex mode; presets are recommended.
- Preserve the extension by default, changing it only through explicit controls.
- Compose numbered names strictly from the user's ordered eligible item list; excluded rows must not consume sequence values.
- Live preview is not a promise of success: the application must revalidate at application time.
- Detect duplicate desired names, invalid Windows names, pre-existing path conflicts, and file state drift. No automatic overwrite. Support safe swap/chain renames, partial results, and undo with conflict checking.
- Windows 11 style light/dark themes, primary `#2D7BC6`, accessible keyboard navigation and scaling.

## T00 exclusions
There is **no** rename engine, Explorer integration, installer, drag/drop, production branding icon, or interactive rename GUI in T00. Do not market the foundation as an operational application.

## Explicit v1.0 non-goals
No AI naming, content edits, cloud sync, tracking, always-on watchers, file movement/sorting to directories, full metadata/EXIF editor, Windows 10 or ARM64 commitments.

## Open implementation decisions for later tasks
- T01: precise selection handoff transport, first-level menu registration and sparse package lifecycle, signing trust and deployment.
- T02: concrete execution journal format, atomicity boundaries, undo persistence scope (baseline: current session), nested parent/child folder rename ordering and network-share differences.
- T03: precise placement of complex rules and preset interaction details.
Choices must be recorded in their task and tested; these are not license to expand scope.
