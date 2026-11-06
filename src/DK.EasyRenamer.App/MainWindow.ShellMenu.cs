using System.Diagnostics;
using System.IO;
using System.Windows;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    // Query-ClassicShell.ps1: 0 registered, 1 available, 3 conflicting, 4 unavailable.
    private int _shellMenuState = 4;

    private async void OnShellMenuLoaded(object sender, RoutedEventArgs e) =>
        await RefreshShellMenuAsync();

    private async Task RefreshShellMenuAsync()
    {
        ShellMenuButton.IsEnabled = false;
        ShellMenuButton.Content = "우클릭 메뉴 확인 중";
        try
        {
            _shellMenuState = await RunShellScriptAsync("Query-ClassicShell.ps1");
        }
        catch (Exception ex) when (ex is IOException or InvalidOperationException or
            System.ComponentModel.Win32Exception or OperationCanceledException)
        {
            _shellMenuState = 4;
        }

        switch (_shellMenuState)
        {
            case 0:
                ShellMenuButton.Content = "우클릭 메뉴 해제";
                ShellMenuButton.ToolTip = "현재 사용자 클래식 탐색기 메뉴 등록 해제";
                ShellMenuButton.IsEnabled = true;
                break;
            case 1:
                ShellMenuButton.Content = "우클릭 메뉴 적용";
                ShellMenuButton.ToolTip = "인증서 없이 클래식 탐색기 메뉴 등록 (Windows 11: 추가 옵션 표시)";
                ShellMenuButton.IsEnabled = true;
                break;
            case 3:
                ShellMenuButton.Content = "우클릭 메뉴 (등록 충돌)";
                ShellMenuButton.ToolTip = "다른 설치 경로에 등록되어 있어 수정하지 않습니다.";
                break;
            default:
                ShellMenuButton.Content = "우클릭 메뉴 (확인 불가)";
                ShellMenuButton.ToolTip = "설치본의 컨텍스트 메뉴 상태를 조회할 수 없습니다.";
                break;
        }
    }

    private async void OnToggleShellMenu(object sender, RoutedEventArgs e)
    {
        if (_shellMenuState is not (0 or 1))
            return;

        bool enabling = _shellMenuState == 1;
        var choice = MessageBox.Show(this,
            enabling
                ? "현재 계정의 클래식 탐색기 우클릭 메뉴를 등록하시겠습니까?\n" +
                  "선택한 파일의 이름은 변경되지 않습니다."
                : "현재 계정의 클래식 탐색기 우클릭 메뉴를 해제하시겠습니까?\n" +
                  "프로그램 자체는 삭제되지 않습니다.",
            "탐색기 우클릭 메뉴", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (choice != MessageBoxResult.Yes)
            return;

        ShellMenuButton.IsEnabled = false;
        try
        {
            int result = await RunShellScriptAsync(
                enabling ? "Register-ClassicShell.ps1" : "Unregister-ClassicShell.ps1");
            if (result != 0)
            {
                MessageBox.Show(this,
                    "탐색기 메뉴 변경이 완료되지 않았습니다. 기존 등록 또는 파일 접근 권한 상태를 확인하세요.",
                    "탐색기 우클릭 메뉴", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            else
            {
                MessageBox.Show(this,
                    "우클릭 메뉴 변경이 완료됐습니다.\n탐색기에 즉시 반영되지 않으면 탐색기를 다시 시작하거나 로그아웃 후 로그인하세요.",
                    "탐색기 우클릭 메뉴", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
        catch (Exception ex) when (ex is IOException or InvalidOperationException or
            System.ComponentModel.Win32Exception or OperationCanceledException)
        {
            MessageBox.Show(this, "탐색기 메뉴 변경 명령을 실행할 수 없습니다.",
                "탐색기 우클릭 메뉴", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            await RefreshShellMenuAsync();
        }
    }

    private static async Task<int> RunShellScriptAsync(string scriptName)
    {
        string script = Path.Combine(AppContext.BaseDirectory, scriptName);
        if (!File.Exists(script))
            return 4;

        string modernPowerShell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "PowerShell", "7", "pwsh.exe");
        string powerShell = File.Exists(modernPowerShell)
            ? modernPowerShell
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell", "v1.0", "powershell.exe");

        var start = new ProcessStartInfo(powerShell)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = AppContext.BaseDirectory
        };
        foreach (string argument in new[]
        {
            "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
            "-File", script, "-InstallDir", AppContext.BaseDirectory
        })
            start.ArgumentList.Add(argument);

        using Process process = Process.Start(start) ??
            throw new InvalidOperationException("PowerShell did not start.");
        using var limit = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        await process.WaitForExitAsync(limit.Token);
        return process.ExitCode;
    }
}
