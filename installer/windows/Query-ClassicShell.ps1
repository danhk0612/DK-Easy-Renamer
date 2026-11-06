# 0 registered by this app, 1 available, 3 conflicting/partial ownership, 4 unavailable.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
try {
    $dir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
    $exe = Join-Path $dir 'DK.EasyRenamer.App.exe'
    $dll = Join-Path $dir 'DK.EasyRenamer.Shell.dll'
    $owner = 'HKCU:\Software\DKEasyRenamer'
    $classes = 'HKCU:\Software\Classes'
    $definitions = @(
        @{ Clsid='{73F9A0E1-982D-4C4E-AB20-987DCA14E930}'; Verb="$classes\*\shell\DK-Easy-Renamer" },
        @{ Clsid='{F7BE1B68-314C-4F75-9F3E-7C3597B42AD1}'; Verb="$classes\Directory\shell\DK-Easy-Renamer" }
    )
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or
        -not (Test-Path -LiteralPath $dll -PathType Leaf)) { exit 4 }
    $found = 0
    foreach ($entry in $definitions) {
        $com = "$classes\CLSID\$($entry.Clsid)\InprocServer32"
        $hasCom = Test-Path -LiteralPath $com
        $hasVerb = Test-Path -LiteralPath $entry.Verb
        if ($hasCom -ne $hasVerb) { exit 3 }
        if ($hasCom) {
            $found++
            if ([string](Get-Item -LiteralPath $com).GetValue('') -ine $dll) { exit 3 }
            $handler = (Get-ItemProperty -LiteralPath $entry.Verb -Name ExplorerCommandHandler -ErrorAction SilentlyContinue).ExplorerCommandHandler
            if ([string]$handler -ne $entry.Clsid) { exit 3 }
        }
    }
    if (Test-Path -LiteralPath $owner) {
        $saved = Get-ItemProperty -LiteralPath $owner -ErrorAction Stop
        if ([string]$saved.ExecutablePath -ine $exe -or [string]$saved.ShellMode -ne 'Classic') {
            exit 3
        }
        if ($found -ne 2) { exit 3 }
        exit 0
    }
    if ($found) { exit 3 }
    # A prior developer-signed MSIX registration must not be overwritten.
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop).Count -gt 0) { exit 3 }
    exit 1
}
catch { exit 4 }
