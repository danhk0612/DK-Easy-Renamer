# Exit codes consumed by the WPF UI:
# 0 = this installation owns the registered context menu
# 1 = not registered, package can be registered using its trusted certificate
# 2 = not registered, package signature/certificate cannot pass preflight
# 3 = a registration exists for a different install location or is inconsistent
# 4 = unable to inspect current state
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
    $resolved = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
    $expectedExe = Join-Path $resolved 'DK.EasyRenamer.App.exe'
    $key = 'HKCU:\Software\DKEasyRenamer'
    $registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
    $recordedExe = ''
    if (Test-Path -LiteralPath $key) {
        $record = Get-ItemProperty -LiteralPath $key -Name ExecutablePath -ErrorAction SilentlyContinue
        if ($null -ne $record -and $null -ne $record.ExecutablePath) {
            $recordedExe = [string]$record.ExecutablePath
        }
    }
    if ($registered.Count -gt 1) { exit 3 }
    if ($recordedExe -and
        -not [string]::Equals($recordedExe,$expectedExe,[StringComparison]::OrdinalIgnoreCase)) {
        exit 3
    }
    if ($registered.Count -eq 1) {
        if (-not $recordedExe) { exit 3 }
        $package = Join-Path $resolved 'DKEasyRenamer.Shell.msix'
        $publisherCheck = Join-Path $resolved 'Test-ShellPublisherTransition.ps1'
        if (-not (Test-Path -LiteralPath $package -PathType Leaf) -or
            -not (Test-Path -LiteralPath $publisherCheck -PathType Leaf)) { exit 3 }
        try { & $publisherCheck -PackagePath $package | Out-Null }
        catch { exit 3 }
        exit 0
    }

    $package = Join-Path $resolved 'DKEasyRenamer.Shell.msix'
    $checkScript = Join-Path $resolved 'Preflight-Shell.ps1'
    if (-not (Test-Path -LiteralPath $expectedExe -PathType Leaf) -or
        -not (Test-Path -LiteralPath $package -PathType Leaf) -or
        -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) { exit 2 }

    try {
        & $checkScript -PackagePath $package | Out-Null
    }
    catch {
        exit 2
    }
    exit 1
}
catch {
    exit 4
}
