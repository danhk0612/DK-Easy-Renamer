using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Windows;
using DK.EasyRenamer.Core;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    // No network activity on startup or in Explorer. Only the user's button invokes this URL.
    private static readonly Uri LatestReleaseApi =
        new("https://api.github.com/repos/danhk0612/DK-Easy-Renamer/releases/latest");

    private async void OnCheckUpdates(object sender, RoutedEventArgs e)
    {
        CheckUpdatesButton.IsEnabled = false;
        try
        {
            using var client = new HttpClient(new HttpClientHandler
            {
                AllowAutoRedirect = false
            })
            {
                Timeout = TimeSpan.FromSeconds(10)
            };
            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "DK-Easy-Renamer/" + (typeof(MainWindow).Assembly.GetName().Version?.ToString(3) ?? "0.0.0"));
            using var response = await client.GetAsync(LatestReleaseApi, HttpCompletionOption.ResponseHeadersRead);
            if (response.StatusCode == HttpStatusCode.NotFound)
            {
                MessageBox.Show(this, "아직 공개된 정식 릴리스가 없습니다. 개발용 시험 설치본은 자동 업데이트 대상이 아닙니다.",
                    "업데이트 확인", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            response.EnsureSuccessStatusCode();
            string json = await response.Content.ReadAsStringAsync();
            StableRelease? release = StableReleaseParser.ParseLatest(json);
            if (release is null)
            {
                MessageBox.Show(this, "공식 GitHub 릴리스 정보를 확인할 수 없습니다.",
                    "업데이트 확인", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            Version current = typeof(MainWindow).Assembly.GetName().Version ?? new Version(0, 0, 0);
            if (!StableReleaseParser.HasUpdate(release, current))
            {
                MessageBox.Show(this,
                    $"최신 정식 버전입니다.\n현재: {current.ToString(3)}\n공개: {release.Version.ToString(3)}",
                    "업데이트 확인", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            string notes = release.ReleaseNotes.Replace("\r\n", "\n").Replace('\r', '\n').Trim();
            if (string.IsNullOrWhiteSpace(notes))
                notes = "변경 내용이 등록되지 않았습니다.";
            else if (notes.Length > 600)
                notes = notes[..600].TrimEnd() + "\n… (전체 내용은 GitHub 릴리스 페이지에서 확인)";

            string announcement =
                $"새 정식 버전 {release.Version.ToString(3)}이 공개됐습니다.\n현재 버전: {current.ToString(3)}\n\n" +
                $"변경 내용:\n{notes}\n\n";

            // No public publisher has been approved. Development/self-signed
            // test installers are not eligible for in-app execution.
            bool approved = PublicUpdatePolicy.TryGetApprovedPublisher(
                out PublicUpdatePublisher? publisher);
            OfficialInstallerAsset? asset = approved
                ? PublicUpdatePolicy.FindNewerInstaller(json, current)
                : null;
            if (publisher is not null && asset is not null)
            {
                var installChoice = MessageBox.Show(this,
                    announcement +
                    $"공식 설치 파일: {asset.FileName}\n\n" +
                    "예: 파일을 다운로드하고 해시·Windows 서명을 검증한 후 설치 여부를 다시 확인합니다.\n" +
                    "아니요: 공식 GitHub 릴리스 페이지를 엽니다.\n" +
                    "취소: 아무 작업도 하지 않습니다.",
                    "정식 업데이트 확인", MessageBoxButton.YesNoCancel, MessageBoxImage.Question);

                if (installChoice == MessageBoxResult.Yes)
                    await DownloadVerifyAndOfferInstallAsync(asset, publisher);
                else if (installChoice == MessageBoxResult.No)
                    OpenOfficialReleasePage(release);
                return;
            }

            string reason = approved
                ? "공식 설치 파일의 이름·크기·해시 정보를 검증할 수 없어 앱 내 설치를 제공하지 않습니다."
                : "무료 배포 설치본은 코드 서명이 없어 앱 내 자동 설치가 비활성화되어 있습니다. 공식 GitHub Release에서 직접 다운로드해 설치하세요.";
            var choice = MessageBox.Show(this,
                announcement + reason + "\n\n공식 GitHub 릴리스 페이지를 브라우저로 여시겠습니까?",
                "새 버전 확인", MessageBoxButton.YesNo, MessageBoxImage.Information);
            if (choice == MessageBoxResult.Yes)
                OpenOfficialReleasePage(release);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            MessageBox.Show(this, "업데이트 정보를 가져오지 못했습니다. 인터넷 연결이나 GitHub 서비스 상태를 확인하세요.",
                "업데이트 확인", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            CheckUpdatesButton.IsEnabled = true;
        }
    }
    private static void OpenOfficialReleasePage(StableRelease release)
    {
        Process.Start(new ProcessStartInfo(release.ReleasePage.AbsoluteUri)
        {
            UseShellExecute = true
        });
    }
}
