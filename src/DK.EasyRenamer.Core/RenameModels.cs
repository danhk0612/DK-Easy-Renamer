namespace DK.EasyRenamer.Core;

/// <summary>Items are already in user-selected order. Excluded entries do not consume numbering.</summary>
public sealed record RenameSelection(string Path, bool Included = true);

public sealed record FileFingerprint(bool IsDirectory, long Length, DateTime LastWriteUtc,
    DateTime CreatedUtc)
{
    public static FileFingerprint Capture(string path)
    {
        if (File.Exists(path))
        {
            var file = new FileInfo(path);
            file.Refresh();
            return new FileFingerprint(false, file.Length, file.LastWriteTimeUtc, file.CreationTimeUtc);
        }
        if (Directory.Exists(path))
        {
            var dir = new DirectoryInfo(path);
            dir.Refresh();
            return new FileFingerprint(true, 0, dir.LastWriteTimeUtc, dir.CreationTimeUtc);
        }
        throw new FileNotFoundException("Selected path does not exist.", path);
    }

    public bool Matches(string path)
    {
        try { return Equals(Capture(path)); }
        catch (IOException) { return false; }
        catch (UnauthorizedAccessException) { return false; }
    }
}

public sealed record RenamePlanItem(string OriginalPath, string TargetPath,
    bool Included, FileFingerprint Snapshot, string? Error = null)
{
    public bool Changed => Included && !StringComparer.Ordinal.Equals(OriginalPath, TargetPath);
    public bool IsValid => Error is null;
}

public sealed record RenamePlan(IReadOnlyList<RenamePlanItem> Items)
{
    public bool IsValid => Items.All(x => x.IsValid);
    public IReadOnlyList<string> Errors => Items
        .Where(x => !x.IsValid).Select(x => x.Error!).ToArray();
}

public sealed record RenameOperation(string Original, string Target, bool IsDirectory,
    FileFingerprint ExpectedAtTarget);

public sealed class RenameUndo
{
    internal RenameUndo(IReadOnlyList<RenameOperation> operations) => Operations = operations;
    internal IReadOnlyList<RenameOperation> Operations { get; }
    internal bool Used { get; set; }
}

public sealed record RenameExecutionResult(bool Succeeded,
    IReadOnlyList<string> Errors, RenameUndo? Undo);
