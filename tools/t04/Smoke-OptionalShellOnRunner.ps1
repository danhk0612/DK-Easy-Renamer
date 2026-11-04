# CI-only test: an untrusted development MSIX must NOT prevent app-only installation.
# Once the matching public .cer is trusted on the disposable runner, the user
# can optionally register and later remove the Explorer integration.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactFolder,
    [Parameter(Mandatory)][string]$AppOnlyArtifactFolder
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
    [Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'Only a disposable Windows GitHub Actions runner may run this test.'
}
$folder = (Resolve-Path -LiteralPath $ArtifactFolder).Path
$setup = @(Get-ChildItem -LiteralPath $folder -Filter 'DK-Easy-Renamer-*-x64-SIGNED-PROBE.exe' -File)
$cer = Join-Path $folder 'DKEasyRenamer-TEST-ONLY.cer'
if ($setup.Count -ne 1 -or -not (Test-Path -LiteralPath $cer -PathType Leaf)) {
    throw 'Expected one signed probe and the matching public-only certificate.'
}
$appOnlyFolder = (Resolve-Path -LiteralPath $AppOnlyArtifactFolder).Path
$appOnlySetups = @(Get-ChildItem -LiteralPath $appOnlyFolder -Filter 'DK-Easy-Renamer-*-x64-APP-ONLY.exe' -File)
if ($appOnlySetups.Count -ne 1) {
    throw 'Expected exactly one standalone-only unsigned test setup.'
}
$public = Get-PfxCertificate -FilePath $cer
$sign = (Get-AuthenticodeSignature -LiteralPath $setup[0].FullName).SignerCertificate
if ($null -eq $sign -or $sign.Thumbprint -ne $public.Thumbprint) {
    throw 'Test setup signer does not match the temporary CI certificate.'
}
$storePath = 'Cert:\LocalMachine\TrustedPeople\' + $public.Thumbprint
if (Test-Path -LiteralPath $storePath) {
    throw 'The test certificate is already trusted before the optional-install test.'
}
$folderPath = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer'
$app = Join-Path $folderPath 'DK.EasyRenamer.App.exe'
$uninstaller = Join-Path $folderPath 'unins000.exe'
if ((Get-AppxPackage -Name 'DKEasyRenamer.Shell') -or (Test-Path -LiteralPath $folderPath)) {
    throw 'Runner has an existing install. Refusing to overwrite it.'
}

function Invoke-Executable([string]$file,[string[]]$args) {
    $process = Start-Process -FilePath $file -ArgumentList $args -Wait -PassThru
    try {
        if ($process.ExitCode -ne 0) {
            throw "Unexpected process exit $($process.ExitCode): $file"
        }
    } finally { $process.Dispose() }
}
function Assert-ApplicationOnly {
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
        throw 'App-only installation did not copy the executable.'
    }
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count -ne 0) {
        throw 'An optional package was unexpectedly registered.'
    }
    if (Test-Path 'HKCU:\Software\DKEasyRenamer') {
        throw 'An optional Explorer registry entry was unexpectedly created.'
    }
}
function Assert-ShellState([int]$expected) {
    & (Join-Path $folderPath 'Query-ShellState.ps1') -InstallDir $folderPath
    if ($LASTEXITCODE -ne $expected) {
        throw "Shell state mismatch: expected $expected, got $LASTEXITCODE."
    }
}

try {
    # The intentionally unsigned, standalone-only package can install without any certificate.
    Invoke-Executable $appOnlySetups[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Assert-ApplicationOnly
    Assert-ShellState 2
    Invoke-Executable $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null

    # A signed (but not trusted) test setup must be able to install the base app.
    # /TASKS= excludes context menu registration. No trust is silently granted.
    Invoke-Executable $setup[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/TASKS=')
    Assert-ApplicationOnly
    Assert-ShellState 2

    $running = Start-Process -FilePath $app -PassThru
    try {
        Start-Sleep -Seconds 3
        $running.Refresh()
        if ($running.HasExited) {
            throw "Unpackaged WPF app failed to start without the MSIX identity (exit $($running.ExitCode))."
        }
    }
    finally {
        if (-not $running.HasExited) { Stop-Process -Id $running.Id -Force -ErrorAction SilentlyContinue }
        $running.Dispose()
    }
    Invoke-Executable $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null

    # Only the isolated test runner receives the matching development .cer.
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
    Invoke-Executable $setup[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/TASKS=shellmenu')
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1') | Out-Null
    Assert-ShellState 0

    # Exercise the same installed scripts used by the application's toggle.
    & (Join-Path $folderPath 'Unregister-Shell.ps1') -InstallDir $folderPath | Out-Null
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count -ne 0 -or
        (Test-Path 'HKCU:\Software\DKEasyRenamer')) {
        throw 'Disabling the menu did not remove the registered package/registry.'
    }
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
        throw 'Disabling the menu removed the base application.'
    }
    Assert-ShellState 1

    & (Join-Path $folderPath 'Register-Shell.ps1') -InstallDir $folderPath | Out-Null
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1') | Out-Null
    Assert-ShellState 0

    Invoke-Executable $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null
    Write-Host 'PASS: unsigned APP-ONLY and untrusted signed setup install base app; trusted package opts into shell; toggle off/on; uninstall.'
    Write-Host 'This is a Windows Server 2025 automated smoke, not interactive Windows 11 UI acceptance.'
}
finally {
    if (Test-Path -LiteralPath $uninstaller -PathType Leaf) {
        $cleanup = Start-Process -FilePath $uninstaller -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
        $cleanup.Dispose()
    }
    if (Test-Path -LiteralPath $storePath) {
        Remove-Item -LiteralPath $storePath -Force -ErrorAction SilentlyContinue
    }
}
