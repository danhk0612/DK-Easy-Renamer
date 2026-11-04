# UX-00: Baseline GUI startup timing on a real Windows 11 workstation.
# Launches ONLY a new empty DK Easy Renamer window, never touches selected files.
[CmdletBinding()]
param(
    [int]$Iterations = 5,
    [string]$ExecutablePath = (Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer\DK.EasyRenamer.App.exe')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Iterations -lt 3 -or $Iterations -gt 20) { throw 'Choose 3 to 20 iterations.' }
if ([Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'UX-00 real device baseline requires Windows 11.'
}
$exe = (Resolve-Path -LiteralPath $ExecutablePath -ErrorAction Stop).Path
$records = @()
for ($i = 1; $i -le $Iterations; $i++) {
    $process = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $exe -PassThru
        $opened = $false
        while ($watch.Elapsed.TotalSeconds -lt 15) {
            Start-Sleep -Milliseconds 50
            $process.Refresh()
            if ($process.HasExited) {
                throw "App exited before showing its main window: $($process.ExitCode)"
            }
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                $opened = $true
                break
            }
        }
        if (-not $opened) { throw 'No accessible application window within 15 seconds.' }
        $watch.Stop()
        $records += [pscustomobject]@{
            Iteration = $i
            VisibleMainWindowMs = [Math]::Round($watch.Elapsed.TotalMilliseconds)
            WindowTitle = $process.MainWindowTitle
        }
    }
    finally {
        $watch.Stop()
        if ($null -ne $process) {
            # Only close the process launched by this test, never another app instance.
            if (-not $process.HasExited) {
                [void]$process.CloseMainWindow()
                if (-not $process.WaitForExit(3000)) {
                    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                }
            }
            $process.Dispose()
        }
    }
}
$records | Format-Table -AutoSize
$measurements = @($records | Select-Object -ExpandProperty VisibleMainWindowMs | Sort-Object)
$mid = [Math]::Floor($measurements.Count / 2)
$median = if ($measurements.Count % 2) { $measurements[$mid] }
          else { ($measurements[$mid-1] + $measurements[$mid]) / 2 }
[pscustomobject]@{
    WindowsBuild = [Environment]::OSVersion.Version.Build
    MeasuredProcess = $exe
    Iterations = $Iterations
    MedianMainWindowMs = $median
    MinMs = $measurements[0]
    MaxMs = $measurements[-1]
}
Write-Host 'Measured process start to Win32 main-window handle only; not Explorer menu latency or full paint.'
