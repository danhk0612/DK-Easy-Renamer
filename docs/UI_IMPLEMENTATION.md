# T03 — Fluent GUI implementation (automated gate / physical test deferred)

## Framework and design
- .NET 10 WPF, WPF-UI 4.3.0 (MIT), package docs: https://www.nuget.org/packages/WPF-UI/4.3.0
- Base color: #2D7BC6, supporting dark/light palettes under App.xaml dynamic resources.
- Window targets 1150×750 with reasonable minimum 870×580, two-column rule editor and file preview list.
- WPF-UI control/theme resource dictionaries and Fluent SymbolIcon icons are used for common actions.
- Original vector app mark: assets/icons/DK-Easy-Renamer.svg (blue document, pencil, file lines).
- The Windows x64 CI invokes tools/t03/Generate-Icon.ps1 before build to generate 16–256px layered ICO and 256px PNG. The icon is embedded into the WPF EXE and copied to the shell external app directory.
- The icon is generated at build time; if building locally, first run the generator. No external image/font redistribution.

## GUI functions
1. Import Explorer-selected file/folder paths through T01 handoff, or add files/folders from dialogs and drag/drop.
2. Sort by natural filename, simple name, created/modified time or size; use direction toggle.
3. Change manual order with multi-row up/down or drag-and-drop; row order is used by Core numbering.
4. Exclude individual files from numbering/apply using the table checkbox.
5. Add, select, reorder, enable/disable, and remove GUI rules.
6. Editors for find/replace, prefix/suffix, remove text, number, N-char deletion, slice, case, extension, dates and advanced regex.
7. Recompute proposed names and show conflict states from RenamePlanner in near-real-time.
8. Apply after confirmation via RenameExecutor; undo last successful operation with snapshot validation.
9. Theme follows system once at launch, with manual light/dark toggle (no system accent override of the brand color).

## Source overview
- App.xaml: WPF-UI theme dictionaries and brand brush resources.
- MainWindow.xaml: UI layout and file table.
- MainWindow.xaml.cs: preview, sorting/rules collection and theme.
- MainWindow.RuleEditor.cs: per-rule interactive GUI fields.
- MainWindow.FileOperations.cs: native file/folder dialogs, drag/drop, sort, apply and undo.
- RenamerUiModels.cs: GUI-only row/rule state.

## Safety
- Applying changes always requires a separate confirmation.
- No unintended recursive renaming: a selected folder itself is renamed, its children are not processed as separate targets unless explicitly selected; nested selected folder+child is rejected by Core.
- Executor refuses collisions/changed sources, does not overwrite targets, and offers in-session undo when possible.
- Changes after applying may create a new preview; unchanged rule list remains available.
- Physical Windows Explorer/visual/DPI/installer/regression testing is **deferred to T04**, not waived.

## CI acceptance vs deferred tests
Automated: NuGet restore, WPF XAML/C# compile, Core filesystem fixture tests, native COM x64 compile, icon generation and unsigned sparse package artifact.
Deferred physical: click/selection handoff, drag/drop ordering feel, dialog ergonomics, DPI 125–200%, high contrast, light/dark readability, actual file/UNC moves, install/remove/upgrade.
