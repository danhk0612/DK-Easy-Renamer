# Removes only the current user's OWNED DK Easy Renamer Explorer identity.
# Never remove an Appx package if its owner, publisher or install path is
# missing, ambiguous or inconsistent with this installed application.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$resolved = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$expectedApp = Join-Path $resolved 'DK.EasyRenamer.App.exe'
$key = 'HKCU:\Software\DKEasyRenamer'

# Inspect everything BEFORE any mutation. A matching package name alone does
# not prove ownership (different public publishers have different families).
$registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($registered.Count -gt 1) {
    throw 'More than one Explorer identity is registered; no removal is safe.'
}

$keyExists = Test-Path -LiteralPath $key
$ownerPath = ''
if ($keyExists) {
    $record = Get-ItemProperty -LiteralPath $key -Name ExecutablePath -ErrorAction SilentlyContinue
    if ($null -ne $record -and $null -ne $record.ExecutablePath) {
        $ownerPath = [string]$record.ExecutablePath
    }
    if ([string]::IsNullOrWhiteSpace($ownerPath) -or
        -not [string]::Equals($ownerPath,$expectedApp,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Explorer registration owner is missing or belongs to another installation; refusing removal.'
    }
}

if ($registered.Count -eq 1) {
    if (-not $keyExists) {
        throw 'Explorer identity exists but this installation has no ownership record; refusing removal.'
    }
    $pkg = $registered[0]
    if ($null -eq $pkg -or
        [string]::IsNullOrWhiteSpace([string]$pkg.PackageFullName)) {
        throw 'Registered Explorer package identity is incomplete; refusing removal.'
    }

    $packageFile = Join-Path $resolved 'DKEasyRenamer.Shell.msix'
    $guard = Join-Path $resolved 'Test-ShellPublisherTransition.ps1'
    if (-not (Test-Path -LiteralPath $packageFile -PathType Leaf) -or
        -not (Test-Path -LiteralPath $guard -PathType Leaf)) {
        throw 'Installed MSIX or publisher comparison guard is missing; refusing removal.'
    }
    # This guard compares the incoming installed MSIX manifest Publisher
    # against the actual registered package; mismatches MUST remain untouched.
    & $guard -PackagePath $packageFile | Out-Null

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop).Count -ne 0) {
        throw 'Explorer identity remains registered; retaining owner record for diagnosis.'
    }
}

# This HKCU record is removed only when it is owned by the current install
# and its registered package is absent or has just been removed successfully.
if ($keyExists) {
    Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
}
Write-Host 'Removed owned per-user Explorer identity (if present). Selected files were not touched.'
