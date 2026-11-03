# Read-only inspection AFTER explicitly uninstalling DK Easy Renamer.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packages = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($packages.Count) {
    throw "App package registration still present: $($packages.PackageFullName -join ', ')"
}
if (Test-Path -Path 'HKCU:\Software\DKEasyRenamer') {
    throw 'Explorer launch registry key is still present.'
}
$defaultApp = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer\DK.EasyRenamer.App.exe'
if (Test-Path -LiteralPath $defaultApp -PathType Leaf) {
    throw "App executable still exists at default location: $defaultApp"
}
Write-Host 'Uninstall static checks passed: no per-user package, launch registry or default EXE.'
Write-Host 'You must still confirm the first-level Explorer menu disappears after a refresh.'
