using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    private const string WindowCaption = "DK Easy Renamer";
    private const int DwmwaCaptionColor = 35;
    private const int DwmwaTextColor = 36;

    // DWM uses COLORREF: 0x00BBGGRR, so #2D7BC6 becomes 0x00C67B2D.
    private const int BrandCaptionBgr = 0x00C67B2D;
    private const int WhiteCaptionBgr = 0x00FFFFFF;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(nint hwnd, int attribute, ref int value, int size);

    [DllImport("user32.dll", EntryPoint = "SetWindowTextW", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowText(nint hwnd, string text);

    private void OnWindowSourceInitialized(object? sender, EventArgs e) => ApplyNativeCaptionStyle();

    private void OnMinimizeWindow(object sender, RoutedEventArgs e) =>
        WindowState = System.Windows.WindowState.Minimized;

    private void OnMaximizeWindow(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == System.Windows.WindowState.Maximized
            ? System.Windows.WindowState.Normal
            : System.Windows.WindowState.Maximized;

    private void OnCloseWindow(object sender, RoutedEventArgs e) => Close();

    private void OnWindowStateChanged(object? sender, EventArgs e)
    {
        if (MaximizeWindowGlyph is not null)
            MaximizeWindowGlyph.Text = WindowState == System.Windows.WindowState.Maximized
                ? "\uE923" : "\uE922";
    }

    private void ApplyNativeCaptionStyle()
    {
        // Preserve native window movement/resizing and caption metadata; WPF draws the three titlebar buttons.
        // Explicitly set its text/colors: a branded caption must not render as a blank blue bar.
        Title = WindowCaption;
        var handle = new WindowInteropHelper(this).Handle;
        if (handle == 0) return;

        SetWindowText(handle, WindowCaption);
        int caption = BrandCaptionBgr;
        int text = WhiteCaptionBgr;
        DwmSetWindowAttribute(handle, DwmwaCaptionColor, ref caption, sizeof(int));
        DwmSetWindowAttribute(handle, DwmwaTextColor, ref text, sizeof(int));
    }
}
