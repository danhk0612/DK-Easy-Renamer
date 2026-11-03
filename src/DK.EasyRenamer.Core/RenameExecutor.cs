namespace DK.EasyRenamer.Core;

/// <summary>
/// Best-effort two-phase rename/rollback with explicit same-session undo.
/// Never overwrites an existing file or directory.
/// </summary>
public static class RenameExecutor
{
    private sealed class Entry(string original, string target, bool isDirectory, FileFingerprint expected)
    {
        public string Original { get; } = original;
        public string Target { get; } = target;
        public string Current { get; set; } = original;
        public bool Directory { get; } = isDirectory;
        public FileFingerprint Expected { get; } = expected;
    }

    public static RenameExecutionResult Apply(RenamePlan plan)
    {
        ArgumentNullException.ThrowIfNull(plan);
        if (!plan.IsValid) return new RenameExecutionResult(false, plan.Errors, null);
        var entries = plan.Items.Where(x => x.Changed)
            .Select(x => new Entry(x.OriginalPath, x.TargetPath, x.Snapshot.IsDirectory, x.Snapshot))
            .ToList();
        return Execute(entries);
    }

    public static RenameExecutionResult Undo(RenameUndo undo)
    {
        ArgumentNullException.ThrowIfNull(undo);
        if (undo.Used)
            return new RenameExecutionResult(false, ["This undo operation was already used."], null);
        var entries = undo.Operations
            .Select(x => new Entry(x.Target, x.Original, x.IsDirectory, x.ExpectedAtTarget))
            .ToList();
        var result = Execute(entries);
        if (result.Succeeded) undo.Used = true;
        return result;
    }

    private static RenameExecutionResult Execute(List<Entry> entries)
    {
        if (entries.Count == 0)
            return new RenameExecutionResult(true, [], new RenameUndo([]));

        // Revalidate before the first write. A new file at a destination blocks execution.
        var originals = new HashSet<string>(entries.Select(x => x.Original), StringComparer.OrdinalIgnoreCase);
        foreach (Entry entry in entries)
        {
            if (!entry.Expected.Matches(entry.Original))
                return Failure("The selected item changed after preview: " + entry.Original);
            if (EntryExists(entry.Target) && !originals.Contains(entry.Target))
                return Failure("Destination is now occupied: " + entry.Target);
        }

        var staged = new List<Entry>();
        try
        {
            // Phase 1 vacates all original paths, allowing swaps/cycles and case-only renames.
            foreach (Entry entry in entries)
            {
                string temp = UniqueTemp(entry.Original);
                Move(entry.Original, temp, entry.Directory);
                entry.Current = temp;
                staged.Add(entry);
            }
            // Phase 2 commits all destinations, with no overwrite.
            foreach (Entry entry in entries)
            {
                Move(entry.Current, entry.Target, entry.Directory);
                entry.Current = entry.Target;
            }

            RenameOperation[] operations = entries.Select(x =>
                new RenameOperation(x.Original, x.Target, x.Directory,
                    FileFingerprint.Capture(x.Target))).ToArray();
            return new RenameExecutionResult(true, [], new RenameUndo(operations));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            var errors = new List<string> { "Rename failed: " + ex.Message };
            // Stage every successfully moved entry again first, so even swaps/cycles
            // can be safely reversed without overwriting another entry.
            var rollbackStaged = new List<Entry>();
            foreach (Entry entry in staged)
            {
                try
                {
                    string temp = UniqueTemp(entry.Current);
                    Move(entry.Current, temp, entry.Directory);
                    entry.Current = temp;
                    rollbackStaged.Add(entry);
                }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException)
                {
                    errors.Add("Rollback staging failed for " + entry.Current + ": " + error.Message);
                }
            }
            foreach (Entry entry in rollbackStaged)
            {
                try
                {
                    Move(entry.Current, entry.Original, entry.Directory);
                    entry.Current = entry.Original;
                }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException)
                {
                    errors.Add("Rollback failed; item remains at " + entry.Current + ": " + error.Message);
                }
            }
            return new RenameExecutionResult(false, errors, null);
        }
    }

    private static RenameExecutionResult Failure(string message) =>
        new(false, [message], null);

    private static bool EntryExists(string path) => File.Exists(path) || Directory.Exists(path);

    private static string UniqueTemp(string original)
    {
        string parent = Path.GetDirectoryName(original)!;
        for (int i = 0; i < 25; i++)
        {
            string path = Path.Combine(parent, ".dkrenamer-" + Guid.NewGuid().ToString("N") + ".tmp");
            if (!EntryExists(path)) return path;
        }
        throw new IOException("Unable to find an unoccupied temporary name.");
    }

    private static void Move(string from, string to, bool isDirectory)
    {
        if (EntryExists(to)) throw new IOException("Target occupied: " + to);
        if (isDirectory) Directory.Move(from, to);
        else File.Move(from, to);
    }
}
