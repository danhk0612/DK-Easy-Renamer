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

            var choice = MessageBox.Show(this,
                $"새 정식 버전 {release.Version.ToString(3)}이 공개됐습니다.\n현재 버전: {current.ToString(3)}\n\n" +
                "공식 GitHub 릴리스 페이지를 브라우저로 여시겠습니까?\n" +
                "설치 파일은 자동 다운로드하거나 실행하지 않습니다.",
                "새 버전 확인", MessageBoxButton.YesNo, MessageBoxImage.Information);
            if (choice == MessageBoxResult.Yes)
            {
                Process.Start(new ProcessStartInfo(release.ReleasePage.AbsoluteUri)
                {
                    UseShellExecute = true
                });
            }
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
}
