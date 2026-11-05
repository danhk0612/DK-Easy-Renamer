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
    public void DriveRootIsNeverReinterpretedAsDriveRelativeOrRenamed()
    {
        using var f = new WorkFolder();
        string root = Path.GetPathRoot(f.Root)!;
        var plan = RenamePlanner.Build([new RenameSelection(root)],
            [new AddTextRule("unsafe_")]);

        Assert.False(plan.IsValid);
        Assert.Equal(root, plan.Items[0].OriginalPath);
        Assert.Equal(root, plan.Items[0].TargetPath);
        Assert.Contains(plan.Errors, error =>
            error.Contains("Root directory cannot be renamed", StringComparison.Ordinal));
        Assert.False(RenameExecutor.Apply(plan).Succeeded);
        Assert.True(Directory.Exists(root));
    }

    [Fact]
    public void DirectoryWithTrailingSeparatorStillUsesNormalRenameRules()
    {
        using var f = new WorkFolder();
        string folder = Path.Combine(f.Root, "oldItems");
        Directory.CreateDirectory(folder);
        var plan = RenamePlanner.Build(
            [new RenameSelection(folder + Path.DirectorySeparatorChar)],
            [new ReplaceRule("old", "new")]);

        Assert.True(plan.IsValid, string.Join("; ", plan.Errors));
        Assert.Equal(folder, plan.Items[0].OriginalPath);
        Assert.Equal(Path.Combine(f.Root, "newItems"), plan.Items[0].TargetPath);
        var applied = RenameExecutor.Apply(plan);
        Assert.True(applied.Succeeded, string.Join("; ", applied.Errors));
        Assert.True(RenameExecutor.Undo(applied.Undo!).Succeeded);
        Assert.True(Directory.Exists(folder));
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
    public void NaturalSortUsesDirectoryNameWithOrWithoutTrailingSeparator()
    {
        using var f = new WorkFolder();
        string two = Path.Combine(f.Root, "folder2");
        string ten = Path.Combine(f.Root, "folder10");
        string one = Path.Combine(f.Root, "folder1");
        Directory.CreateDirectory(two);
        Directory.CreateDirectory(ten);
        Directory.CreateDirectory(one);

        var selection = new[]
        {
            new RenameSelection(ten + Path.DirectorySeparatorChar),
            new RenameSelection(two),
            new RenameSelection(one + Path.DirectorySeparatorChar)
        };
        var sorted = RenameSelectionSorter.Sort(selection, RenameSortField.NaturalName);
        Assert.Equal([selection[2], selection[1], selection[0]], sorted);

        var descending = RenameSelectionSorter.Sort(selection, RenameSortField.NaturalName, descending: true);
        Assert.Equal([selection[0], selection[1], selection[2]], descending);
    }

    [Fact]
    public void NameSortKeepsSelectedDirectoryPathUnmodified()
    {
        using var f = new WorkFolder();
        string alpha = Path.Combine(f.Root, "Alpha");
        string beta = Path.Combine(f.Root, "Beta");
        Directory.CreateDirectory(alpha);
        Directory.CreateDirectory(beta);
        string alphaWithSeparator = alpha + Path.DirectorySeparatorChar;
        var sorted = RenameSelectionSorter.Sort(
            [new RenameSelection(beta), new RenameSelection(alphaWithSeparator)], RenameSortField.Name);
        Assert.Equal([alphaWithSeparator, beta], sorted.Select(x => x.Path));
    }

    [Fact]
    public void DescendingSizeSortKeepsUserOrderForEqualFileSizes()
    {
        using var f = new WorkFolder();
        string first = f.File("first.txt", "same");
        string bigger = f.File("bigger.txt", "longer contents");
        string second = f.File("second.txt", "also");
        var selection = new[] { new RenameSelection(first), new RenameSelection(bigger), new RenameSelection(second) };

        var sorted = RenameSelectionSorter.Sort(selection, RenameSortField.Size, descending: true);
        Assert.Equal([bigger, first, second], sorted.Select(x => x.Path));

        var ascending = RenameSelectionSorter.Sort(selection, RenameSortField.Size);
        Assert.Equal([first, second, bigger], ascending.Select(x => x.Path));
    }

    [Fact]
    public void DescendingModifiedDateSortKeepsUserOrderForEqualTimes()
    {
        using var f = new WorkFolder();
        string first = f.File("one.txt");
        string newer = f.File("newer.txt");
        string second = f.File("two.txt");
        var olderTime = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var newerTime = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        System.IO.File.SetLastWriteTimeUtc(first, olderTime);
        System.IO.File.SetLastWriteTimeUtc(second, olderTime);
        System.IO.File.SetLastWriteTimeUtc(newer, newerTime);
        var selection = new[] { new RenameSelection(first), new RenameSelection(newer), new RenameSelection(second) };

        var sorted = RenameSelectionSorter.Sort(selection, RenameSortField.ModifiedUtc, descending: true);
        Assert.Equal([newer, first, second], sorted.Select(x => x.Path));
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

    [Theory]
    [InlineData("COM¹")]
    [InlineData("com².txt")]
    [InlineData("COM³.backup.tar")]
    [InlineData("LPT¹")]
    [InlineData("lpt².csv")]
    [InlineData("LPT³.txt")]
    public void SuperscriptDeviceNamesAreRejectedByWindowsNameValidation(string deviceName)
    {
        Assert.False(RenamePlanner.ValidName(deviceName));
    }

    [Fact]
    public void PlannerBlocksSuperscriptDeviceNameBeforeAnyFilesystemWrite()
    {
        using var f = new WorkFolder();
        string source = f.File("original.txt", "untouched");
        var plan = RenamePlanner.Build([new RenameSelection(source)],
            [new ReplaceRule("original", "COM¹")]);
        Assert.False(plan.IsValid);
        Assert.Contains(plan.Errors, e => e.Contains("invalid or reserved", StringComparison.OrdinalIgnoreCase));
        var result = RenameExecutor.Apply(plan);
        Assert.False(result.Succeeded);
        Assert.Equal("untouched", System.IO.File.ReadAllText(source));
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
    [Fact]
    public void NumberOnlyReplacesStemButPreservesExtensionAndCanUndo()
    {
        using var f = new WorkFolder();
        string first = f.File("18.svg", "first");
        string second = f.File("19.svg", "second");
        var selection = new[] { new RenameSelection(first), new RenameSelection(second) };
        var plan = RenamePlanner.Build(selection, [
            new SequenceRule(Start: 0, Step: 1, Width: 2, Separator: "_",
                AtStart: true, ReplaceStem: true)
        ]);
        Assert.True(plan.IsValid, string.Join("; ", plan.Errors));
        Assert.Equal("00.svg", Path.GetFileName(plan.Items[0].TargetPath));
        Assert.Equal("01.svg", Path.GetFileName(plan.Items[1].TargetPath));

        var applied = RenameExecutor.Apply(plan);
        Assert.True(applied.Succeeded, string.Join("; ", applied.Errors));
        Assert.Equal("first", System.IO.File.ReadAllText(plan.Items[0].TargetPath));
        Assert.Equal("second", System.IO.File.ReadAllText(plan.Items[1].TargetPath));
        Assert.True(RenameExecutor.Undo(applied.Undo!).Succeeded);
        Assert.Equal("first", System.IO.File.ReadAllText(first));
        Assert.Equal("second", System.IO.File.ReadAllText(second));
    }

    [Fact]
    public void SequenceRuleHandlesMinimumLongWithoutDoubleMinusOrOverflow()
    {
        var context = new RenameRuleContext(0, false, default, default);
        var original = new RenameName("photo", ".png");
        var rule = new SequenceRule(Start: long.MinValue, Width: 3, ReplaceStem: true);
        Assert.Equal("-9223372036854775808.png", rule.Apply(original, context).FullName);

        using var folder = new WorkFolder();
        string source = folder.File("photo.png", "unchanged");
        var plan = RenamePlanner.Build([new RenameSelection(source)], [rule]);
        Assert.True(plan.IsValid, string.Join("; ", plan.Errors));
        Assert.Equal("-9223372036854775808.png", Path.GetFileName(plan.Items[0].TargetPath));
        var apply = RenameExecutor.Apply(plan);
        Assert.True(apply.Succeeded, string.Join("; ", apply.Errors));
        Assert.Equal("unchanged", System.IO.File.ReadAllText(plan.Items[0].TargetPath));
        Assert.True(RenameExecutor.Undo(apply.Undo!).Succeeded);
        Assert.Equal("unchanged", System.IO.File.ReadAllText(source));
    }

    [Theory]
    [InlineData(-7L, "-007")]
    [InlineData(0L, "000")]
    [InlineData(7L, "007")]
    public void SequenceRuleRetainsExistingPaddingBehavior(long number, string expected)
    {
        var rule = new SequenceRule(Start: number, Width: 3, ReplaceStem: true);
        Assert.Equal(expected + ".txt", rule.Apply(new RenameName("name", ".txt"),
            new RenameRuleContext(0, false, default, default)).FullName);
    }

    [Fact]
    public void NumberPlacementDefaultAndSuffixRemainUnchanged()
    {
        var context = new RenameRuleContext(0, false, default, default);
        var name = new RenameName("18", ".svg");
        Assert.Equal("00_18.svg", new SequenceRule(Start: 0, Width: 2).Apply(name, context).FullName);
        Assert.Equal("18_00.svg", new SequenceRule(Start: 0, Width: 2, AtStart: false).Apply(name, context).FullName);
    }

}
