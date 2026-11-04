# Removes only the current user's DK Easy Renamer identity and matching registry values.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedApp = Join-Path ([System.IO.Path]::GetFullPath($InstallDir)) 'DK.EasyRenamer.App.exe'
$key = 'HKCU:\Software\DKEasyRenamer'
if (Test-Path -LiteralPath $key) {
    $owner = Get-ItemProperty -LiteralPath $key -Name ExecutablePath -ErrorAction SilentlyContinue
    if ($null -ne $owner -and $owner.ExecutablePath -and
        -not [string]::Equals([string]$owner.ExecutablePath, $expectedApp,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Another installation owns the Explorer registration. It will not be removed.'
    }
}
foreach ($pkg in @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)) {
    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
}
$key = 'HKCU:\Software\DKEasyRenamer'
if (Test-Path -LiteralPath $key) {
    $record = Get-ItemProperty -LiteralPath $key -Name ExecutablePath -ErrorAction SilentlyContinue
    if ($null -ne $record -and
        [string]::Equals([string]$record.ExecutablePath, $expectedApp,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
    }
}
Write-Host 'Removed per-user Explorer identity. Selected files were not touched.'
