using System.Windows;

namespace DK.EasyRenamer.App;

public partial class MainWindow : Window
{
    public MainWindow(IReadOnlyList<string> selectedPaths, string? notice)
    {
        InitializeComponent();
        SelectedPaths.ItemsSource = selectedPaths;
        CountText.Text = $"선택 항목: {selectedPaths.Count}개";
        StatusText.Text = notice ?? "탐색기에서 파일·폴더를 선택한 뒤 DK Easy Renamer를 실행해 주세요.";
    }
}
