using System.IO;
using System.Windows;
using DK.EasyRenamer.Core;

namespace DK.EasyRenamer.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        string[] paths = [];
        string? notice = null;
        if (e.Args.Length == 2 && e.Args[0] == "--selection-file")
        {
            string full = Path.GetFullPath(e.Args[1]);
            string temp = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
            bool expected = string.Equals(Path.GetDirectoryName(full), temp, StringComparison.OrdinalIgnoreCase)
                && Path.GetFileName(full).StartsWith("DKR", StringComparison.OrdinalIgnoreCase)
                && Path.GetExtension(full).Equals(".tmp", StringComparison.OrdinalIgnoreCase);
            if (!expected)
                notice = "올바르지 않은 선택 항목 전달 경로입니다.";
            else
            {
                try
                {
                    using var stream = File.OpenRead(full);
                    paths = SelectionHandoff.Read(stream);
                    notice = $"탐색기에서 {paths.Length}개 항목을 전달받았습니다. 아직 이름을 변경하지 않습니다.";
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException)
                {
                    notice = $"선택 항목을 읽지 못했습니다: {ex.Message}";
                }
                finally
                {
                    // This deletes the transport packet ONLY, not any selected item.
                    try { File.Delete(full); } catch (IOException) { } catch (UnauthorizedAccessException) { }
                }
            }
        }
        else if (e.Args.Length > 0)
            notice = "지원하지 않는 실행 인수입니다.";

        var window = new MainWindow(paths, notice);
        MainWindow = window;
        window.Show();
    }
}
