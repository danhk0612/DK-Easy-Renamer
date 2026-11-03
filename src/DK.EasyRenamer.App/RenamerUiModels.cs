using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using DK.EasyRenamer.Core;

namespace DK.EasyRenamer.App;

public sealed class FileRow : INotifyPropertyChanged
{
    private string _fullPath;
    private bool _included = true;
    private int _number;
    private string _previewName = "";
    private string _status = "유지";

    public FileRow(string path)
    {
        _fullPath = Path.GetFullPath(path);
        _previewName = Path.GetFileName(_fullPath);
    }

    public string FullPath
    {
        get => _fullPath;
        set
        {
            _fullPath = value;
            Notify();
            Notify(nameof(FileName));
            Notify(nameof(ParentPath));
        }
    }
    public string FileName => Path.GetFileName(_fullPath);
    public string ParentPath => Path.GetDirectoryName(_fullPath) ?? "";
    public bool Included
    {
        get => _included;
        set { if (_included != value) { _included = value; Notify(); } }
    }
    public int Number
    {
        get => _number;
        set { _number = value; Notify(); }
    }
    public string PreviewName
    {
        get => _previewName;
        set { _previewName = value; Notify(); }
    }
    public string Status
    {
        get => _status;
        set { _status = value; Notify(); }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void Notify([CallerMemberName] string? property = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(property));
}

public enum RuleKind
{
    Replace,
    AddText,
    RemoveText,
    Sequence,
    Trim,
    Slice,
    Case,
    Extension,
    Date,
    Regex
}

public sealed class RuleEditorItem : INotifyPropertyChanged
{
    private bool _enabled = true;
    public RuleEditorItem(RuleKind kind) => Kind = kind;

    public RuleKind Kind { get; }
    public string DisplayName => Kind switch
    {
        RuleKind.Replace => "문자열 찾기 · 바꾸기",
        RuleKind.AddText => "접두어 / 접미어",
        RuleKind.RemoveText => "문자열 제거",
        RuleKind.Sequence => "순번 붙이기",
        RuleKind.Trim => "앞·뒤 N글자 제거",
        RuleKind.Slice => "위치·길이로 추출 / 제거",
        RuleKind.Case => "대소문자 변경",
        RuleKind.Extension => "확장자 변경",
        RuleKind.Date => "날짜 삽입",
        RuleKind.Regex => "고급 · 정규식 치환",
        _ => Kind.ToString()
    };

    public bool Enabled
    {
        get => _enabled;
        set { _enabled = value; PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Enabled))); }
    }

    public string Search { get; set; } = "";
    public string Replacement { get; set; } = "";
    public string Text { get; set; } = "";
    public bool AtStart { get; set; } = true;
    public bool IgnoreCase { get; set; }
    public long StartNumber { get; set; } = 1;
    public long Step { get; set; } = 1;
    public int Width { get; set; } = 3;
    public string Separator { get; set; } = "_";
    public int Count { get; set; } = 1;
    public int SliceStart { get; set; }
    public int SliceLength { get; set; } = 1;
    public bool KeepSlice { get; set; } = true;
    public CaseMode CaseChange { get; set; } = CaseMode.Lower;
    public string Extension { get; set; } = "jpg";
    public FileDateKind DateKind { get; set; } = FileDateKind.ModifiedUtc;
    public string DateFormat { get; set; } = "yyyyMMdd";

    public RenameRule Build()
    {
        RenameRule rule = Kind switch
    {
        RuleKind.Replace => new ReplaceRule(Search, Replacement, IgnoreCase),
        RuleKind.AddText => new AddTextRule(Text, AtStart),
        RuleKind.RemoveText => new RemoveTextRule(Text, IgnoreCase),
        RuleKind.Sequence => new SequenceRule(StartNumber, Step, Width, Separator, AtStart),
        RuleKind.Trim => new TrimCharactersRule(Count, AtStart),
        RuleKind.Slice => new SliceRule(SliceStart, SliceLength, KeepSlice),
        RuleKind.Case => new CaseRule(CaseChange),
        RuleKind.Extension => new ExtensionRule(Extension),
        RuleKind.Date => new DateRule(DateKind, DateFormat, AtStart, Separator),
        RuleKind.Regex => new RegexReplaceRule(Search, Replacement, IgnoreCase),
        _ => throw new ArgumentOutOfRangeException(nameof(Kind))
        };
        return rule with { Enabled = Enabled };
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}

public sealed record RuleChoice(string Label, RuleKind Kind);
public sealed record SortChoice(string Label, RenameSortField Field);
