using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    private void RenderSelectedRule()
    {
        if (RuleFields is null) return;
        RuleFields.Children.Clear();
        if (RulesList.SelectedItem is not RuleEditorItem item)
        {
            RuleFields.Children.Add(new TextBlock
            {
                Text = "규칙을 추가하면 이곳에 설정 항목이 나타납니다.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = (Brush)FindResource("MutedBrush"),
                Margin = new Thickness(0, 8, 0, 0)
            });
            return;
        }

        RuleFields.Children.Add(new TextBlock
        {
            Text = item.DisplayName,
            Foreground = (Brush)FindResource("TitleBrush"),
            FontSize = 15,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 12)
        });
        switch (item.Kind)
        {
            case RuleKind.Replace:
                AddTextInput("찾을 문자열", item.Search, v => item.Search = v);
                AddTextInput("바꿀 문자열", item.Replacement, v => item.Replacement = v);
                AddBooleanInput("대소문자 구분하지 않기", item.IgnoreCase, v => item.IgnoreCase = v);
                break;
            case RuleKind.AddText:
                AddTextInput("추가할 문자열", item.Text, v => item.Text = v);
                AddBooleanInput("파일명 앞에 추가 (해제 시 뒤에 추가)",
                    item.AtStart, v => item.AtStart = v);
                break;
            case RuleKind.RemoveText:
                AddTextInput("삭제할 문자열", item.Text, v => item.Text = v);
                AddBooleanInput("대소문자 구분하지 않기", item.IgnoreCase, v => item.IgnoreCase = v);
                break;
            case RuleKind.Sequence:
                AddIntegerInput("시작 번호", item.StartNumber, v => item.StartNumber = v);
                AddIntegerInput("증가값", item.Step, v => item.Step = v);
                AddIntegerInput("자릿수", item.Width, v => item.Width = checked((int)v));
                AddTextInput("구분자", item.Separator, v => item.Separator = v);
                AddBooleanInput("파일명 앞에 순번 (해제 시 뒤에 순번)",
                    item.AtStart, v => item.AtStart = v);
                break;
            case RuleKind.Trim:
                AddIntegerInput("제거할 글자 수", item.Count, v => item.Count = checked((int)v));
                AddBooleanInput("앞에서 제거 (해제 시 뒤에서 제거)",
                    item.AtStart, v => item.AtStart = v);
                break;
            case RuleKind.Slice:
                AddIntegerInput("시작 위치 (0부터)", item.SliceStart, v => item.SliceStart = checked((int)v));
                AddIntegerInput("글자 수", item.SliceLength, v => item.SliceLength = checked((int)v));
                AddBooleanInput("범위만 남기기 (해제 시 범위 삭제)",
                    item.KeepSlice, v => item.KeepSlice = v);
                break;
            case RuleKind.Case:
                AddOptions("대소문자 변환", ["모두 대문자", "모두 소문자", "첫 글자 대문자"],
                    (int)item.CaseChange, n => item.CaseChange = (DK.EasyRenamer.Core.CaseMode)n);
                break;
            case RuleKind.Extension:
                AddTextInput("새 확장자 (점 생략 가능)", item.Extension, v => item.Extension = v);
                AddNote("확장자를 명시적으로 변경합니다. 이 규칙이 없으면 원본 확장자를 유지합니다.");
                break;
            case RuleKind.Date:
                AddOptions("날짜 선택", ["생성일 (UTC)", "수정일 (UTC)"],
                    (int)item.DateKind, n => item.DateKind = (DK.EasyRenamer.Core.FileDateKind)n);
                AddTextInput("날짜 형식", item.DateFormat, v => item.DateFormat = v);
                AddTextInput("구분자", item.Separator, v => item.Separator = v);
                AddBooleanInput("파일명 앞에 날짜", item.AtStart, v => item.AtStart = v);
                AddNote("예: yyyyMMdd → 20261103. 날짜는 UTC 기준입니다.");
                break;
            case RuleKind.Regex:
                AddTextInput("정규식 패턴", item.Search, v => item.Search = v);
                AddTextInput("치환 문자열", item.Replacement, v => item.Replacement = v);
                AddBooleanInput("대소문자 무시", item.IgnoreCase, v => item.IgnoreCase = v);
                AddNote("고급 기능입니다. 일반적인 작업은 전용 규칙을 사용하세요.");
                break;
        }
    }

    private void AddTextInput(string label, string value, Action<string> set)
    {
        AddLabel(label);
        var input = new TextBox
        {
            Text = value,
            MinHeight = 34,
            VerticalContentAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 11)
        };
        input.TextChanged += (_, _) =>
        {
            set(input.Text);
            _ruleInputError = null;
            _justApplied = false;
            RefreshPreview();
        };
        RuleFields.Children.Add(input);
    }

    private void AddIntegerInput(string label, long value, Action<long> set)
    {
        AddLabel(label);
        var input = new TextBox
        {
            Text = value.ToString(System.Globalization.CultureInfo.InvariantCulture),
            MinHeight = 34,
            VerticalContentAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 11)
        };
        input.TextChanged += (_, _) =>
        {
            if (long.TryParse(input.Text, out long result))
            {
                try { set(result); _ruleInputError = null; }
                catch (OverflowException) { _ruleInputError = label + ": 허용 범위를 초과했습니다."; }
            }
            else _ruleInputError = label + ": 유효한 정수를 입력하세요.";
            _justApplied = false;
            RefreshPreview();
        };
        RuleFields.Children.Add(input);
    }

    private void AddBooleanInput(string label, bool value, Action<bool> set)
    {
        var input = new CheckBox
        {
            Content = label,
            IsChecked = value,
            Margin = new Thickness(0, 3, 0, 13),
            Foreground = (Brush)FindResource("TitleBrush")
        };
        void Changed(object? sender, RoutedEventArgs args)
        {
            set(input.IsChecked == true);
            _justApplied = false;
            RefreshPreview();
        }
        input.Checked += Changed;
        input.Unchecked += Changed;
        RuleFields.Children.Add(input);
    }

    private void AddOptions(string label, string[] choices, int selected, Action<int> set)
    {
        AddLabel(label);
        var input = new ComboBox
        {
            ItemsSource = choices,
            SelectedIndex = selected,
            MinHeight = 34,
            Margin = new Thickness(0, 0, 0, 11)
        };
        input.SelectionChanged += (_, _) =>
        {
            if (input.SelectedIndex < 0) return;
            set(input.SelectedIndex);
            _justApplied = false;
            RefreshPreview();
        };
        RuleFields.Children.Add(input);
    }

    private void AddLabel(string value)
    {
        RuleFields.Children.Add(new TextBlock
        {
            Text = value,
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 12,
            Margin = new Thickness(0, 0, 0, 5)
        });
    }

    private void AddNote(string value)
    {
        RuleFields.Children.Add(new TextBlock
        {
            Text = value,
            TextWrapping = TextWrapping.Wrap,
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 11,
            Margin = new Thickness(0, 2, 0, 12)
        });
    }
}
