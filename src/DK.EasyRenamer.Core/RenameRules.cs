using System.Globalization;
using System.Text.RegularExpressions;

namespace DK.EasyRenamer.Core;

public sealed record RenameName(string Stem, string Extension)
{
    public string FullName => Stem + Extension;
}

public sealed record RenameRuleContext(int Index, bool IsDirectory, DateTime CreatedUtc, DateTime ModifiedUtc);

/// <summary>Pure, sequential name transformation. Extension is protected unless an explicit rule edits it.</summary>
public abstract record RenameRule
{
    public bool Enabled { get; init; } = true;
    public abstract RenameName Apply(RenameName name, RenameRuleContext context);
}

public sealed record ReplaceRule(string Search, string Replacement, bool IgnoreCase = false) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (string.IsNullOrEmpty(Search)) throw new ArgumentException("Find text cannot be empty.");
        return name with
        {
            Stem = name.Stem.Replace(Search, Replacement,
                IgnoreCase ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal)
        };
    }
}

public sealed record AddTextRule(string Text, bool AtStart = true) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context) =>
        name with { Stem = AtStart ? Text + name.Stem : name.Stem + Text };
}

public sealed record RemoveTextRule(string Text, bool IgnoreCase = false) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (string.IsNullOrEmpty(Text)) throw new ArgumentException("Remove text cannot be empty.");
        return name with
        {
            Stem = name.Stem.Replace(Text, "",
                IgnoreCase ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal)
        };
    }
}

public sealed record SequenceRule(long Start = 1, long Step = 1, int Width = 3,
    string Separator = "_", bool AtStart = true, bool ReplaceStem = false) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (Width is < 1 or > 16 || Step <= 0) throw new ArgumentOutOfRangeException(nameof(Width));
        long number = checked(Start + context.Index * Step);
        string numberText = number.ToString(CultureInfo.InvariantCulture);
        string digits = number >= 0
            ? numberText.PadLeft(Width, '0')
            : "-" + numberText[1..].PadLeft(Width, '0');
        return name with { Stem = ReplaceStem ? digits : AtStart ? digits + Separator + name.Stem : name.Stem + Separator + digits };
    }
}

public sealed record TrimCharactersRule(int Count, bool FromStart = true) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (Count < 0) throw new ArgumentOutOfRangeException(nameof(Count));
        int len = Math.Min(Count, name.Stem.Length);
        return name with { Stem = FromStart ? name.Stem[len..] : name.Stem[..(name.Stem.Length - len)] };
    }
}

public sealed record SliceRule(int Start, int Length, bool KeepSlice = true) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (Start < 0 || Length < 0 || Start > name.Stem.Length)
            throw new ArgumentOutOfRangeException(nameof(Start));
        int end = Math.Min(name.Stem.Length, checked(Start + Length));
        string stem = KeepSlice ? name.Stem[Start..end] : name.Stem[..Start] + name.Stem[end..];
        return name with { Stem = stem };
    }
}

public enum CaseMode { Upper, Lower, FirstLetterUpper }
public sealed record CaseRule(CaseMode Mode) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        string stem = Mode switch
        {
            CaseMode.Upper => name.Stem.ToUpperInvariant(),
            CaseMode.Lower => name.Stem.ToLowerInvariant(),
            CaseMode.FirstLetterUpper => name.Stem.Length == 0 ? name.Stem
                : char.ToUpperInvariant(name.Stem[0]) + name.Stem[1..],
            _ => throw new ArgumentOutOfRangeException(nameof(Mode))
        };
        return name with { Stem = stem };
    }
}

/// <summary>The only basic rule allowed to modify a file extension.</summary>
public sealed record ExtensionRule(string NewExtension) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        if (context.IsDirectory) return name;
        string ext = string.IsNullOrEmpty(NewExtension) ? "" :
            (NewExtension.StartsWith('.') ? NewExtension : "." + NewExtension);
        return name with { Extension = ext };
    }
}

public enum FileDateKind { CreatedUtc, ModifiedUtc }
public sealed record DateRule(FileDateKind Kind, string Format = "yyyyMMdd",
    bool AtStart = true, string Separator = "_") : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        var date = Kind == FileDateKind.CreatedUtc ? context.CreatedUtc : context.ModifiedUtc;
        string stamp = date.ToString(Format, CultureInfo.InvariantCulture);
        return name with { Stem = AtStart ? stamp + Separator + name.Stem : name.Stem + Separator + stamp };
    }
}

public sealed record RegexReplaceRule(string Pattern, string Replacement,
    bool IgnoreCase = false) : RenameRule
{
    public override RenameName Apply(RenameName name, RenameRuleContext context)
    {
        var options = RegexOptions.CultureInvariant |
            (IgnoreCase ? RegexOptions.IgnoreCase : RegexOptions.None);
        string result = Regex.Replace(name.Stem, Pattern, Replacement, options,
            TimeSpan.FromMilliseconds(200));
        return name with { Stem = result };
    }
}
