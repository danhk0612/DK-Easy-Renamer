# T02 — Rename Engine Design and Verification

## Scope
The Core library is a deterministic, WPF-independent engine; it does not integrate into the user-facing GUI until T03.

### User-controlled ordering
Selection order is authoritative for numbering. Natural sorting uses numeric groups, with other supported keys: name, creation date, modification date, and size. Excluded entries remain visible but do not consume sequence numbers. Caller-driven manual reorder is represented by the input list order. Both ascending and descending sorting preserve the original user order for equal sort keys (e.g., equal file sizes or modification timestamps). Name and natural-name sorting use actual folder names even when an incoming selected directory path ends with a separator; original selection paths are unchanged.

### Rules
Pure ordered rules: find/replace; add/remove text; numbering (start, step, width, position, separator, including the full signed 64-bit start range without negative-value overflow); remove N chars; extract/remove slice; case; explicit extension; creation/modification date; regex with bounded evaluation. Rules operate on the stem by default. Extensions change only using an explicit extension rule. Rule enablement is per rule.

### Preview and safety
The planner preserves drive/share root separators and refuses root-directory renames instead of treating drive roots as drive-relative paths. It checks source existence, filename validity, Windows reserved names (including `COM¹`–`COM³` and `LPT¹`–`LPT³`, with or without extensions), duplicates and destination occupancy. The preview performs **no file mutation**. It also fingerprints each source (type, size, creation and modification time). Apply revalidates snapshots and targets before any write. No file overwrite.

### Apply and undo
Executor performs two-phase renames using unique temporary sibling paths: first vacate all sources, then move to final names. This supports swaps, chains and case-only renames. On failure, attempt a two-phase rollback and disclose any remaining paths; the filesystem cannot promise an atomic multi-file transaction.

Successful actions produce an in-memory undo token, using the resulting fingerprints. Undo also revalidates destinations and cannot overwrite external changes. Tokens are one-use after successful undo, but not persisted across process restarts.

### Explicit current constraint
Selecting an ancestor directory and an item inside it for simultaneous rename is **rejected**, not silently processed. Recursive enumeration/parent-child path dependency handling remains for subsequent design/review. Each selected directory itself may be renamed and its contents move with it unchanged.

### Test policy
All filesystem integration tests create unique temporary folders and clean them up. CI runs on Windows and executes fixture tests, but does not interact with actual Explorer, user's folders, network drives or GUI.

### Deferred real-world checks
T04 will check Explorer source ordering, Korean Unicode and UNC, long paths, network shares, file access denial, mass operations, recovery from partial failure and UI confirmation.
