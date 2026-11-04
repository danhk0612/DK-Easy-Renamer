using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using DK.EasyRenamer.Core;
using Wpf.Ui.Appearance;

namespace DK.EasyRenamer.App;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<FileRow> _rows = [];
    private readonly ObservableCollection<RuleEditorItem> _rules = [];
    private RenamePlan? _plan;
    private RenameUndo? _undo;
    private string? _ruleInputError;
    private bool _initializing = true;
    private bool _justApplied;
    private readonly List<(FileRow Row, string Original)> _lastPathChanges = [];
    private Point _dragStart;
    private FileRow? _dragSource;

    public MainWindow(IReadOnlyList<string> selectedPaths, string? notice, string? quickMode = null)
    {
        InitializeComponent();

        FilesGrid.ItemsSource = _rows;
        RulesList.ItemsSource = _rules;
        RuleChoiceBox.ItemsSource = Enum.GetValues<RuleKind>()
            .Select(k => new RuleChoice(new RuleEditorItem(k).DisplayName, k)).ToArray();
        RuleChoiceBox.SelectedIndex = 0;
        SortChoiceBox.ItemsSource = new SortChoice[]
        {
            new("파일명 · 자연 숫자순", RenameSortField.NaturalName),
            new("파일명 · 일반순", RenameSortField.Name),
            new("생성일", RenameSortField.CreatedUtc),
            new("수정일", RenameSortField.ModifiedUtc),
            new("파일 크기", RenameSortField.Size)
        };
        SortChoiceBox.SelectedIndex = 0;
        // Start in a coherent light palette instead of mixing system Mica with custom brushes.
        ApplicationThemeManager.Apply(ApplicationTheme.Light, Wpf.Ui.Controls.WindowBackdropType.None, updateAccent: false);
        UpdatePalette();

        AddPaths(selectedPaths);
        DetailText.Text = notice ?? "탐색기에서 파일을 선택하거나 파일을 이 창으로 드래그하세요.";
        _initializing = false;
        // A quick command still enters the existing preview-and-confirmation workflow.
        // Nothing is renamed until the user explicitly clicks Apply and confirms.
        RuleKind? initialKind = quickMode switch
        {
            "sequence" => RuleKind.Sequence,
            "replace" => RuleKind.Replace,
            _ => null
        };
        if (initialKind.HasValue)
        {
            var rule = new RuleEditorItem(initialKind.Value);
            _rules.Add(rule);
            RulesList.SelectedItem = rule;
        }
        RenderSelectedRule();
        RefreshPreview();
    }

    private void OnToggleTheme(object sender, RoutedEventArgs e)
    {
        ApplicationTheme next = ApplicationThemeManager.GetAppTheme() == ApplicationTheme.Dark
            ? ApplicationTheme.Light : ApplicationTheme.Dark;
        ApplicationThemeManager.Apply(next, Wpf.Ui.Controls.WindowBackdropType.None, updateAccent: false);
        UpdatePalette();
        ApplyNativeCaptionStyle();
    }

    private void UpdatePalette()
    {
        bool dark = ApplicationThemeManager.GetAppTheme() == ApplicationTheme.Dark;
        SetBrush("CanvasBrush", dark ? "#191D25" : "#F7F9FC");
        SetBrush("SurfaceBrush", dark ? "#262C36" : "#FFFFFF");
        SetBrush("StrokeBrush", dark ? "#434D5C" : "#DFE6EF");
        SetBrush("TitleBrush", dark ? "#F1F5F9" : "#1F2937");
        SetBrush("MutedBrush", dark ? "#A9BACB" : "#64748B");
        SetBrush("SelectedBrush", dark ? "#243A50" : "#E8F2FC");
        SetBrush("BrandBrush", "#2D7BC6");
        SetBrush("BrandHoverBrush", "#2266AA");
        SetBrush("ErrorBrush", dark ? "#F18C96" : "#CF4754");
        SetBrush("SuccessBrush", dark ? "#69C8A5" : "#21866C");
        // Explicit opaque canvas: WPF-UI backdrop managers must not leave a black window beneath light controls.
        Background = (Brush)FindResource("CanvasBrush");
        Foreground = (Brush)FindResource("TitleBrush");
    }

    private static void SetBrush(string key, string hex)
    {
        Application.Current.Resources[key] = new BrushConverter().ConvertFromString(hex)!;
    }

    private void RefreshPreview()
    {
        if (_initializing) return;
        Reindex();
        if (_justApplied)
        {
            ApplyButton.IsEnabled = false;
            UndoButton.IsEnabled = _undo is not null;
            StatusText.Text = "이름 변경 적용 완료";
            return;
        }

        _plan = null;
        ApplyButton.IsEnabled = false;
        UndoButton.IsEnabled = _undo is not null;
        if (_ruleInputError is not null)
        {
            StatusText.Text = "설정 오류: " + _ruleInputError;
            return;
        }

        try
        {
            RenameRule[] rules = _rules.Select(x => x.Build()).ToArray();
            var plan = RenamePlanner.Build(
                _rows.Select(x => new RenameSelection(x.FullPath, x.Included)), rules);
            _plan = plan;
            int changed = 0;
            for (int i = 0; i < _rows.Count; i++)
            {
                FileRow row = _rows[i];
                RenamePlanItem entry = plan.Items[i];
                row.PreviewName = Path.GetFileName(entry.TargetPath);
                row.Status = !entry.Included ? "제외" : entry.Error is not null ? "충돌" :
                    entry.Changed ? "변경 예정" : "유지";
                if (entry.Changed && entry.Error is null) changed++;
            }
            int errors = plan.Items.Count(x => x.Error is not null);
            StatusText.Text = $"{_rows.Count}개 중 {changed}개 변경 예정 · 충돌 {errors}개";
            if (errors > 0)
                DetailText.Text = plan.Errors[0];
            else if (_rows.Count == 0)
                DetailText.Text = "파일이나 폴더를 추가해 주세요.";
            else
                DetailText.Text = "미리보기는 실제 변경 전 결과입니다. 적용 시 한 번 더 파일 상태를 검사합니다.";
            ApplyButton.IsEnabled = plan.IsValid && changed > 0;
        }
        catch (Exception ex) when (ex is ArgumentException or IOException or
            InvalidOperationException or OverflowException or
            System.Text.RegularExpressions.RegexMatchTimeoutException)
        {
            StatusText.Text = "미리보기 오류";
            DetailText.Text = ex.Message;
        }
    }

    private void Reindex()
    {
        for (int i = 0; i < _rows.Count; i++) _rows[i].Number = i + 1;
    }

    private void OnRowPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(FileRow.Included))
        {
            _justApplied = false;
            RefreshPreview();
        }
    }

    private void AddPaths(IEnumerable<string> paths)
    {
        var existing = new HashSet<string>(_rows.Select(x => x.FullPath),
            StringComparer.OrdinalIgnoreCase);
        int added = 0;
        foreach (string path in paths)
        {
            string full;
            try { full = Path.GetFullPath(path); }
            catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException)
            {
                continue;
            }
            if ((!File.Exists(full) && !Directory.Exists(full)) || !existing.Add(full)) continue;
            var row = new FileRow(full);
            row.PropertyChanged += OnRowPropertyChanged;
            _rows.Add(row);
            added++;
        }
        if (added > 0) _justApplied = false;
        RefreshPreview();
    }

    private void OnAddRule(object sender, RoutedEventArgs e)
    {
        if (RuleChoiceBox.SelectedItem is not RuleChoice selected) return;
        var item = new RuleEditorItem(selected.Kind);
        _rules.Add(item);
        RulesList.SelectedItem = item;
        _justApplied = false;
        RefreshPreview();
    }

    private void OnRemoveRule(object sender, RoutedEventArgs e)
    {
        if (RulesList.SelectedItem is not RuleEditorItem selected) return;
        _rules.Remove(selected);
        if (_rules.Count > 0) RulesList.SelectedIndex = _rules.Count - 1;
        _justApplied = false;
        RefreshPreview();
    }

    private void OnRuleUp(object sender, RoutedEventArgs e) => MoveRule(-1);
    private void OnRuleDown(object sender, RoutedEventArgs e) => MoveRule(1);

    private void MoveRule(int offset)
    {
        if (RulesList.SelectedItem is not RuleEditorItem item) return;
        int from = _rules.IndexOf(item), to = from + offset;
        if (to < 0 || to >= _rules.Count) return;
        _rules.Move(from, to);
        RulesList.SelectedItem = item;
        _justApplied = false;
        RefreshPreview();
    }

    private void OnSelectedRuleChanged(object sender, SelectionChangedEventArgs e)
    {
        _ruleInputError = null;
        RenderSelectedRule();
    }

    private void OnRuleEnabledChanged(object sender, RoutedEventArgs e)
    {
        _justApplied = false;
        RefreshPreview();
    }
}
