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

            string undoNotice = _undo is null
                ? "앱을 종료하면 현재 미리보기 및 편집 중인 규칙이 유지되지 않을 수 있습니다."
                : "현재 세션에 실행 취소 가능한 이름 변경 기록이 있습니다.\n" +
                  "설치 중 프로그램이 종료되면 실행 취소 기록이 사라집니다.";

            var consent = MessageBox.Show(this,
                $"설치본 {asset.FileName}의 SHA-256과 Windows 게시자 서명 검증이 완료됐습니다.\n\n" +
                undoNotice + "\n\n" +
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

            using Process? installer = Process.Start(new ProcessStartInfo(verifiedFile)
            {
                UseShellExecute = true
            });
            if (installer is null)
                throw new InvalidOperationException("설치 프로그램을 시작할 수 없습니다.");

            // Let the existing Inno Setup lifecycle close the app when needed.
            // The unique staged directory must stay intact while Setup is running.
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
