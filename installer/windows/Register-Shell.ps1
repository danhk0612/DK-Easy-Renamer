# Per-user shell package registration. Caller is the non-elevated owning user.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$resolved = (Resolve-Path -LiteralPath $InstallDir).Path
$packageFile = Join-Path $resolved 'DKEasyRenamer.Shell.msix'
$appFile = Join-Path $resolved 'DK.EasyRenamer.App.exe'
$comDll = Join-Path $resolved 'DK.EasyRenamer.Shell.dll'
$iconFile = Join-Path $resolved 'DK-Easy-Renamer.ico'
foreach ($file in @($packageFile,$appFile,$comDll,$iconFile)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required installation file missing: $file" }
}

# Appx validates both the MSIX signature and its trust. Unsigned CI probes fail here.
$existing = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
foreach ($pkg in $existing) {
    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
}
Add-AppxPackage -Path $packageFile -ExternalLocation $resolved -ErrorAction Stop
$registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($registered.Count -ne 1) { throw 'Package registration could not be verified.' }

$key = 'HKCU:\Software\DKEasyRenamer'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name 'ExecutablePath' -Value $appFile
Set-ItemProperty -Path $key -Name 'IconPath' -Value $iconFile
Write-Host "Registered per-user Explorer command: $($registered[0].PackageFullName)"
