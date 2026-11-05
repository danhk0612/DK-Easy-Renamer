namespace DK.EasyRenamer.Core;

/// <summary>Builds a read-only rename preview; never modifies source or destination paths.</summary>
public static class RenamePlanner
{
    private static readonly StringComparer PathComparer = StringComparer.OrdinalIgnoreCase;
    private static readonly HashSet<string> Reserved = new(StringComparer.OrdinalIgnoreCase)
    {
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5",
        "COM6", "COM7", "COM8", "COM9", "COM¹", "COM²", "COM³",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7",
        "LPT8", "LPT9", "LPT¹", "LPT²", "LPT³"
    };

    public static RenamePlan Build(IEnumerable<RenameSelection> selection,
        IReadOnlyList<RenameRule> rules)
    {
        ArgumentNullException.ThrowIfNull(selection);
        ArgumentNullException.ThrowIfNull(rules);
        var list = new List<RenamePlanItem>();
        int index = 0;
        foreach (RenameSelection selected in selection)
        {
            string path;
            try { path = Path.GetFullPath(selected.Path).TrimEnd(Path.DirectorySeparatorChar); }
            catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException)
            {
                list.Add(new RenamePlanItem(selected.Path, selected.Path, selected.Included,
                    new FileFingerprint(false, 0, default, default), "Invalid source path."));
                continue;
            }
            FileFingerprint state;
            try { state = FileFingerprint.Capture(path); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                list.Add(new RenamePlanItem(path, path, selected.Included,
                    new FileFingerprint(false, 0, default, default), "Selected item is missing or inaccessible."));
                continue;
            }

            if (!selected.Included)
            {
                list.Add(new RenamePlanItem(path, path, false, state));
                continue;
            }

            string? error = null;
            string target = path;
            try
            {
                if (Path.GetPathRoot(path)?.TrimEnd(Path.DirectorySeparatorChar) ==
                    path.TrimEnd(Path.DirectorySeparatorChar))
                    throw new ArgumentException("Root directory cannot be renamed.");

                string originalName = Path.GetFileName(path);
                string ext = state.IsDirectory ? "" : Path.GetExtension(originalName);
                string stem = state.IsDirectory ? originalName : originalName[..^ext.Length];
                var name = new RenameName(stem, ext);
                var context = new RenameRuleContext(index, state.IsDirectory, state.CreatedUtc, state.LastWriteUtc);
                foreach (RenameRule rule in rules)
                {
                    if (rule.Enabled) name = rule.Apply(name, context);
                }
                if (!ValidName(name.FullName))
                    throw new ArgumentException("The proposed name is invalid or reserved in Windows.");
                string parent = Path.GetDirectoryName(path)!;
                target = Path.Combine(parent, name.FullName);
            }
            catch (Exception ex) when (ex is ArgumentException or OverflowException or
                System.Text.RegularExpressions.RegexMatchTimeoutException)
            {
                error = ex.Message;
            }

            list.Add(new RenamePlanItem(path, target, true, state, error));
            index++;
        }

        var allSources = new HashSet<string>(list.Select(x => x.OriginalPath), PathComparer);
        var sourceCounts = list.GroupBy(x => x.OriginalPath, PathComparer)
            .ToDictionary(x => x.Key, x => x.Count(), PathComparer);
        var changedSources = new HashSet<string>(
            list.Where(x => x.Changed && x.Error is null).Select(x => x.OriginalPath), PathComparer);
        var targets = list.Where(x => x.Included && x.Error is null)
            .GroupBy(x => x.TargetPath, PathComparer)
            .ToDictionary(x => x.Key, x => x.Count(), PathComparer);

        // Rename of an ancestor and its descendant in the same plan must be
        // a separate future feature; reject rather than making incorrect paths.
        var dirSources = list.Where(x => x.Snapshot.IsDirectory && x.Included)
            .Select(x => x.OriginalPath).ToArray();

        for (int i = 0; i < list.Count; i++)
        {
            RenamePlanItem item = list[i];
            if (item.Error is not null) continue;
            string? error = null;
            if (sourceCounts[item.OriginalPath] > 1)
                error = "The same source was selected more than once.";
            else if (item.Included && dirSources.Any(parent =>
                !PathComparer.Equals(parent, item.OriginalPath) &&
                item.OriginalPath.StartsWith(parent + Path.DirectorySeparatorChar,
                    StringComparison.OrdinalIgnoreCase)))
                error = "Nested selected directory paths must be renamed separately.";
            else if (item.Included && targets.TryGetValue(item.TargetPath, out int count) && count > 1)
                error = "Two or more selected items would have the same name.";
            else if (item.Included && item.Changed &&
                (File.Exists(item.TargetPath) || Directory.Exists(item.TargetPath)) &&
                !changedSources.Contains(item.TargetPath))
                error = "Destination already exists and will not be overwritten.";
            else if (item.Included && item.Changed && allSources.Contains(item.TargetPath) &&
                     !changedSources.Contains(item.TargetPath))
                error = "Destination is occupied by an unchanged selected item.";
            if (error is not null) list[i] = item with { Error = error };
        }
        return new RenamePlan(list);
    }

    public static bool ValidName(string name)
    {
        if (string.IsNullOrEmpty(name) || name is "." or ".." ||
            name.Length > 255 || name.EndsWith(' ') || name.EndsWith('.'))
            return false;
        foreach (char c in name)
            if (c < 32 || c is '<' or '>' or ':' or '"' or '/' or '\\' or '|' or '?' or '*')
                return false;
        string beforeDot = name.Split('.')[0];
        return !Reserved.Contains(beforeDot);
    }
}
