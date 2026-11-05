using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Windows;
using DK.EasyRenamer.Core;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    /// <summary>
    /// This path is reachable only after a reviewed public signing identity is
    /// compiled into PublicUpdatePolicy and a stable official asset is selected.
    /// No background polling or automatic installation is performed.
    /// </summary>
    private async Task DownloadVerifyAndOfferInstallAsync(
        OfficialInstallerAsset asset, PublicUpdatePublisher publisher)
    {
        string? verifiedFile = null;
        bool launched = false;
        try
        {
            using var client = new HttpClient(new HttpClientHandler
            {
                AllowAutoRedirect = false
            })
            {
                Timeout = TimeSpan.FromMinutes(10)
            };
            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "DK-Easy-Renamer/" +
                (typeof(MainWindow).Assembly.GetName().Version?.ToString(3) ?? "0.0.0"));

            string stagingRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DK Easy Renamer", "Updates");
            verifiedFile = await VerifiedInstallerDownloader.DownloadAsync(
                client, asset, stagingRoot);

            // A matching GitHub digest alone does not prove a trusted publisher.
            if (!await VerifyPublicInstallerAsync(verifiedFile, asset, publisher))
            {
                MessageBox.Show(this,
                    "다운로드 파일의 Windows 서명 또는 승인된 게시자 검증에 실패했습니다.\n" +
                    "파일을 실행하지 않고 삭제합니다.",
                    "업데이트 설치 차단", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // Installing with the optional task unchecked removes an existing
            // Explorer registration. Preserve the user's current choice.
            int shellState = await RunShellScriptAsync("Query-ShellState.ps1");
            if (shellState is not (0 or 1 or 2))
            {
                MessageBox.Show(this,
                    "현재 탐색기 우클릭 메뉴 등록 상태를 확인할 수 없어 업데이트 설치를 중단합니다.\n" +
                    "기존 프로그램과 메뉴 등록은 변경되지 않습니다.",
                    "업데이트 설치 차단", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            string shellNotice = shellState == 0
                ? "현재 탐색기 우클릭 메뉴 등록을 유지하도록 설치 옵션을 전달합니다."
                : "현재 탐색기 우클릭 메뉴가 등록되지 않아 앱만 업데이트합니다.";

            string undoNotice = _undo is null
                ? "앱을 종료하면 현재 미리보기 및 편집 중인 규칙이 유지되지 않을 수 있습니다."
                : "현재 세션에 실행 취소 가능한 이름 변경 기록이 있습니다.\n" +
                  "설치 중 프로그램이 종료되면 실행 취소 기록이 사라집니다.";

            var consent = MessageBox.Show(this,
                $"설치본 {asset.FileName}의 SHA-256과 Windows 게시자 서명 검증이 완료됐습니다.\n\n" +
                undoNotice + "\n" +
                shellNotice + "\n\n" +
                "지금 설치 프로그램을 실행하시겠습니까?\n" +
                "설치 과정에서 현재 앱이 종료될 수 있습니다.",
                "검증된 업데이트 설치", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (consent != MessageBoxResult.Yes)
                return;

            // Recheck immediately before handoff. A downloaded executable is never
            // run merely because it was once hash-verified or came from GitHub.
            if (!await VerifyPublicInstallerAsync(verifiedFile, asset, publisher))
            {
                MessageBox.Show(this,
                    "실행 직전 파일 무결성 또는 Windows 서명 재검증에 실패했습니다.\n" +
                    "설치를 중단합니다.",
                    "업데이트 설치 차단", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // Inno Setup can close this WPF process during an update. Launch a
            // separate, one-shot helper which verifies the signed installer AGAIN,
            // runs Setup, waits for its process tree, and removes only its own
            // finished staging file. The application does not spawn a resident agent.
            string helper = Path.Combine(AppContext.BaseDirectory, "Invoke-VerifiedUpdate.ps1");
            if (!File.Exists(helper))
                throw new InvalidOperationException("업데이트 실행 보조 스크립트가 없습니다.");

            string modernPowerShell = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "PowerShell", "7", "pwsh.exe");
            string powerShell = File.Exists(modernPowerShell)
                ? modernPowerShell
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                    "WindowsPowerShell", "v1.0", "powershell.exe");

            var handoff = new ProcessStartInfo(powerShell)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = AppContext.BaseDirectory
            };
            foreach (string argument in new[]
            {
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-File", helper, "-InstallerPath", verifiedFile,
                "-ExpectedSha256", asset.Sha256,
                "-ExpectedSignerSubject", publisher.Subject,
                "-ExpectedSignerThumbprint", publisher.Thumbprint
            })
                handoff.ArgumentList.Add(argument);
            // Keep the optional Explorer registration in its current state.
            if (shellState == 0)
                handoff.ArgumentList.Add("-PreserveShellMenu");

            using Process? worker = Process.Start(handoff);
            if (worker is null)
                throw new InvalidOperationException("업데이트 실행 보조 프로세스를 시작할 수 없습니다.");

            // The detached helper now owns this particular staged installer.
            // Deleting it here could interrupt an update after the app is closed.
            launched = true;
        }
        catch (Exception ex) when (ex is HttpRequestException or InvalidDataException or
            IOException or UnauthorizedAccessException or OperationCanceledException or
            Win32Exception or InvalidOperationException)
        {
            MessageBox.Show(this,
                "업데이트 파일을 다운로드·검증하거나 설치 프로그램을 시작하지 못했습니다.\n" +
                "프로그램은 변경되지 않았습니다.",
                "업데이트 처리 실패", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            if (!launched && verifiedFile is not null)
            {
                // Only this new download's unique staging directory is owned by us.
                string? folder = Path.GetDirectoryName(verifiedFile);
                if (folder is not null)
                {
                    try
                    {
                        if (Directory.Exists(folder))
                            Directory.Delete(folder, recursive: true);
                    }
                    catch (IOException) { /* Antivirus may briefly hold the file. */ }
                    catch (UnauthorizedAccessException) { /* Do not touch other files. */ }
                }
            }
        }
    }

    private static async Task<bool> VerifyPublicInstallerAsync(
        string downloadedFile, OfficialInstallerAsset asset, PublicUpdatePublisher publisher)
    {
        string script = Path.Combine(AppContext.BaseDirectory, "Validate-PublicInstaller.ps1");
        if (!File.Exists(script) || !File.Exists(downloadedFile))
            return false;

        string pwsh = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "PowerShell", "7", "pwsh.exe");
        string powershell = File.Exists(pwsh)
            ? pwsh
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell", "v1.0", "powershell.exe");

        var start = new ProcessStartInfo(powershell)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = AppContext.BaseDirectory
        };
        foreach (string argument in new[]
        {
            "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
            "-File", script,
            "-InstallerPath", downloadedFile,
            "-ExpectedSha256", asset.Sha256,
            "-ExpectedSignerSubject", publisher.Subject,
            "-ExpectedSignerThumbprint", publisher.Thumbprint
        })
            start.ArgumentList.Add(argument);

        using Process? process = Process.Start(start);
        if (process is null)
            return false;

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        try
        {
            await process.WaitForExitAsync(timeout.Token);
            return process.ExitCode == 0;
        }
        catch (OperationCanceledException)
        {
            if (!process.HasExited)
                process.Kill(entireProcessTree: true);
            return false;
        }
    }
}
