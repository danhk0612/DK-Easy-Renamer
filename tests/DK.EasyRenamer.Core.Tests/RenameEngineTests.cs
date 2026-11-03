using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class RenameEngineTests
{
    private sealed class WorkFolder : IDisposable
    {
        public string Root { get; } = Path.Combine(Path.GetTempPath(),
            "DK-EasyRenamer-tests-" + Guid.NewGuid().ToString("N"));

        public WorkFolder() => Directory.CreateDirectory(Root);

        public string File(string name, string contents = "content")
        {
            string path = Path.Combine(Root, name);
            System.IO.File.WriteAllText(path, contents);
            return path;
        }

        public void Dispose()
        {
            if (Directory.Exists(Root)) Directory.Delete(Root, recursive: true);
        }
    }

    private sealed record SwapRule() : RenameRule
    {
        public override RenameName Apply(RenameName name, RenameRuleContext context) =>
            name with
            {
                Stem = name.Stem switch
                {
                    "left" => "right",
                    "right" => "left",
                    _ => name.Stem
                }
            };
    }

    [Fact]
    public void PlannerIsReadOnlyAndHonorsOrderAndExcludedNumbering()
    {
        using var f = new WorkFolder();
        string ten = f.File("photo10.jpg");
        string two = f.File("photo2.jpg");
        string skip = f.File("skip.txt");
        var selection = new[] {
            new RenameSelection(ten), new RenameSelection(skip, false), new RenameSelection(two)
        };
        var plan = RenamePlanner.Build(selection,
        [
            new ReplaceRule("photo", "여행"),
            new SequenceRule(Start: 7, Step: 2, Width: 3, AtStart: true)
        ]);
        Assert.True(plan.IsValid, string.Join(", ", plan.Errors));
        Assert.Equal("007_여행10.jpg", Path.GetFileName(plan.Items[0].TargetPath));
        Assert.Equal(skip, plan.Items[1].TargetPath);
        Assert.Equal("009_여행2.jpg", Path.GetFileName(plan.Items[2].TargetPath));
        Assert.True(System.IO.File.Exists(ten));
        Assert.True(System.IO.File.Exists(two));
        Assert.False(System.IO.File.Exists(plan.Items[0].TargetPath));
    }

    [Fact]
    public void NaturalSortHandlesNumbersAndSortDirection()
    {
        using var f = new WorkFolder();
        var files = new[] { f.File("file10.txt"), f.File("file2.txt"), f.File("file1.txt") };
        var sorted = RenameSelectionSorter.Sort(files.Select(x => new RenameSelection(x)), RenameSortField.NaturalName);
        Assert.Equal(["file1.txt", "file2.txt", "file10.txt"],
            sorted.Select(x => Path.GetFileName(x.Path)));
        var reverse = RenameSelectionSorter.Sort(sorted, RenameSortField.NaturalName, true);
        Assert.Equal(["file10.txt", "file2.txt", "file1.txt"],
            reverse.Select(x => Path.GetFileName(x.Path)));
    }

    [Fact]
    public void RulePipelinePreservesExtensionUnlessExplicitlyChanged()
    {
        using var f = new WorkFolder();
        string a = f.File("abcdef.JPG");
        var rules = new RenameRule[]
        {
            new TrimCharactersRule(2),
            new SliceRule(0, 2, KeepSlice: false),
            new CaseRule(CaseMode.Lower),
            new AddTextRule("prefix_"),
            new ExtensionRule("png")
        };
        var plan = RenamePlanner.Build([new RenameSelection(a)], rules);
        Assert.True(plan.IsValid);
        Assert.Equal("prefix_ef.png", Path.GetFileName(plan.Items[0].TargetPath));
        var protectedPlan = RenamePlanner.Build([new RenameSelection(a)],
            [new CaseRule(CaseMode.Lower)]);
        Assert.Equal("abcdef.JPG", Path.GetFileName(protectedPlan.Items[0].TargetPath));
    }

    [Fact]
    public void DuplicateTargetsAndReservedNamesAreRejected()
    {
        using var f = new WorkFolder();
        string a = f.File("photo1.txt"), b = f.File("photo2.txt");
        var collision = RenamePlanner.Build([new(a), new(b)],
            [new RegexReplaceRule("[12]$", "")]);
        Assert.False(collision.IsValid);
        Assert.Equal(2, collision.Errors.Count);
        var reserved = RenamePlanner.Build([new(a)],
            [new ReplaceRule("photo1", "CON")]);
        Assert.False(reserved.IsValid);
        Assert.False(RenamePlanner.ValidName("nul.txt"));
        Assert.False(RenamePlanner.ValidName("has?.txt"));
        Assert.False(RenamePlanner.ValidName("trailing."));
    }

    [Fact]
    public void ExistingDestinationIsNeverOverwritten()
    {
        using var f = new WorkFolder();
        string a = f.File("a.txt", "A"), b = f.File("b.txt", "B");
        var plan = RenamePlanner.Build([new(a)], [new ReplaceRule("a", "b")]);
        Assert.False(plan.IsValid);
        var result = RenameExecutor.Apply(plan);
        Assert.False(result.Succeeded);
        Assert.Equal("A", System.IO.File.ReadAllText(a));
        Assert.Equal("B", System.IO.File.ReadAllText(b));
    }

    [Fact]
    public void TwoPhaseSwapAndUndoRestoreBothOriginalFiles()
    {
        using var f = new WorkFolder();
        string left = f.File("left.txt", "LEFT");
        string right = f.File("right.txt", "RIGHT");
        var plan = RenamePlanner.Build([new(left), new(right)], [new SwapRule()]);
        Assert.True(plan.IsValid, string.Join(";", plan.Errors));
        var apply = RenameExecutor.Apply(plan);
        Assert.True(apply.Succeeded, string.Join(";", apply.Errors));
        Assert.Equal("RIGHT", System.IO.File.ReadAllText(left));
        Assert.Equal("LEFT", System.IO.File.ReadAllText(right));
        Assert.NotNull(apply.Undo);
        var undo = RenameExecutor.Undo(apply.Undo);
        Assert.True(undo.Succeeded, string.Join(";", undo.Errors));
        Assert.Equal("LEFT", System.IO.File.ReadAllText(left));
        Assert.Equal("RIGHT", System.IO.File.ReadAllText(right));
        Assert.False(RenameExecutor.Undo(apply.Undo).Succeeded);
    }

    [Fact]
    public void ChangedFileAfterPreviewBlocksExecution()
    {
        using var f = new WorkFolder();
        string path = f.File("one.txt", "base");
        var plan = RenamePlanner.Build([new(path)], [new AddTextRule("renamed_")]);
        System.IO.File.AppendAllText(path, "-changed");
        var result = RenameExecutor.Apply(plan);
        Assert.False(result.Succeeded);
        Assert.True(System.IO.File.Exists(path));
        Assert.False(System.IO.File.Exists(plan.Items[0].TargetPath));
    }

    [Fact]
    public void CaseOnlyRenameWorksAndCanBeUndone()
    {
        using var f = new WorkFolder();
        string oldPath = f.File("mixed.txt");
        var plan = RenamePlanner.Build([new(oldPath)], [new CaseRule(CaseMode.Upper)]);
        Assert.True(plan.IsValid);
        var applied = RenameExecutor.Apply(plan);
        Assert.True(applied.Succeeded, string.Join(",", applied.Errors));
        Assert.Equal("MIXED.txt", Path.GetFileName(plan.Items[0].TargetPath).Replace(".TXT", ".txt"));
        var restored = RenameExecutor.Undo(applied.Undo!);
        Assert.True(restored.Succeeded, string.Join(",", restored.Errors));
        Assert.True(System.IO.File.Exists(oldPath));
    }

    [Fact]
    public void DirectoryItselfRenamesButItsContentsAreUnchanged()
    {
        using var f = new WorkFolder();
        string source = Path.Combine(f.Root, "FolderOLD");
        Directory.CreateDirectory(source);
        System.IO.File.WriteAllText(Path.Combine(source, "child.txt"), "child");
        var plan = RenamePlanner.Build([new(source)], [new ReplaceRule("OLD", "NEW")]);
        Assert.True(plan.IsValid);
        var applied = RenameExecutor.Apply(plan);
        Assert.True(applied.Succeeded, string.Join(",", applied.Errors));
        Assert.True(System.IO.File.Exists(Path.Combine(f.Root, "FolderNEW", "child.txt")));
        var undone = RenameExecutor.Undo(applied.Undo!);
        Assert.True(undone.Succeeded, string.Join(",", undone.Errors));
        Assert.True(System.IO.File.Exists(Path.Combine(source, "child.txt")));
    }

    [Fact]
    public void NestedFolderAndItsChildMustBeProcessedSeparately()
    {
        using var f = new WorkFolder();
        string folder = Path.Combine(f.Root, "Photos");
        Directory.CreateDirectory(folder);
        string child = Path.Combine(folder, "child.jpg");
        System.IO.File.WriteAllText(child, "data");
        var plan = RenamePlanner.Build([new(folder), new(child)], [new AddTextRule("new_")]);
        Assert.False(plan.IsValid);
        Assert.Contains(plan.Errors, e => e.Contains("Nested selected directory"));
    }

    [Fact]
    public void UndoProtectsFileModifiedAfterApply()
    {
        using var f = new WorkFolder();
        string source = f.File("data.txt", "before");
        var plan = RenamePlanner.Build([new(source)], [new AddTextRule("new_")]);
        var apply = RenameExecutor.Apply(plan);
        Assert.True(apply.Succeeded);
        System.IO.File.AppendAllText(plan.Items[0].TargetPath, "-after");
        var undo = RenameExecutor.Undo(apply.Undo!);
        Assert.False(undo.Succeeded);
        Assert.True(System.IO.File.Exists(plan.Items[0].TargetPath));
    }

    [Fact]
    public void DisabledRuleDoesNotChangePreview()
    {
        using var f = new WorkFolder();
        string source = f.File("file.txt");
        var plan = RenamePlanner.Build([new(source)],
            [new AddTextRule("no_") { Enabled = false }]);
        Assert.Equal(source, plan.Items[0].TargetPath);
        Assert.Empty(plan.Errors);
    }
}
