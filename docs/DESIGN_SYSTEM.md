# DK Easy Renamer Design System v1.0

## Brand
- Primary: `#2D7BC6`
- Primary hover: `#2266AA`
- Selected tint: `#E8F2FC`
- Success: `#21866C`
- Error: `#CF4754`
- Light canvas: `#F7F9FC`; light surface: `#FFFFFF`; primary text: `#1F2937`.
- Dark canvas: `#191D25`; dark surface: `#262C36`; dark accent: `#64A8E9`.

## Layout
- Default starting window target about 1100 x 720 px; resizable, with a practical minimum.
- Left column: rename rule list and editing (~30–35%).
- Right: large sortable/drag-reorderable item list (~65–70%) showing source, target and status.
- Bottom action/status bar shows selected/eligible counts, conflict count, Apply and Undo.
- Typography: standard Windows 11 UI font fallback, compact but readable spacing, 125–200% DPI checks.

## Interaction
- Use standard controls for routine rules. For numbering expose start, step, width, prefix/suffix position and separator; never require special `${...}` syntax.
- Sorting is explicit. Drag/manual operations switch to manual order; recomputing preview does not reorder.
- Keyboard focus, tooltip labels, accessible contrast and error states are part of T03 acceptance.
- Icons: consistent Fluent-style iconography; own app icon concept is blue document + pen + reorder arrows; must be readable at 16/20/24 px and included as .ico for Windows executable/Explorer. License-check all external glyph assets.
- Default theme follows OS, user-selectable light/dark if deemed necessary during T03.

## Current implementation
T00 shows a basic branded informational placeholder (not a finished Fluent screen). Complete responsive composition, theme resources, glyphs and application icon belong to T03.
