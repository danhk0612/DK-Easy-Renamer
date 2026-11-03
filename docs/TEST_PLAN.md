# Validation and Test Plan

## T00 foundation gate
- `dotnet restore DK-Easy-Renamer.sln` on Windows .NET 10 SDK.
- `dotnet build DK-Easy-Renamer.sln -c Release --no-restore`.
- `dotnet test DK-Easy-Renamer.sln -c Release --no-build`.
- Start GUI on Windows 11; show placeholder; confirm **no file writes or Explorer registration**.
- Record Windows Actions CI run status. Passing compilation alone is not proof of T01/T02+ readiness.

## T01 shell gate
- First-level menu exists for files, folders, multi-selection; exact name/unicode/UNC paths; repeated invocations; package registration/removal; explorer restart and standard user.
- Test on real Windows 11; CI cannot substitute for actual Explorer UI proof.

## T02 engine gate
- Natural numbering `1, 2, 10`; manual order remains stable; excluded rows don't consume numbering.
- Rule combinations and deterministic recomputation; extensions protected by default.
- Invalid Win32 names, duplicate targets, existing destination, case-only renames and swaps/chains.
- Originals never overwritten; accurate partial success and safe undo/revalidation.
- Use disposable fixtures, never actual user folders.

## T03 GUI gate
- Mouse/keyboard selection and reorder, sorting and preview stability.
- Korean paths, high DPI, light/dark, focus and legibility.
- Rule controls expose all routine options without magic syntax.

## T04 integrated gate
- 1,000+ entries, long paths, network/UNC, nested folders, restricted paths, external modifications, program restart behavior and performance.
- Evidence must distinguish environment constraints and failures from passes.

## T05 delivery gate
- Fresh install; signed/trusted deployment plan; repair/upgrade; uninstall leaving no orphan menu/COM registrations; artifact checksums and MIT/third-party license notices.
