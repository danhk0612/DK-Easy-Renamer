# Disposable Windows Server 2025 CI upgrade test: 0.1.2 -> 0.1.3.
# Both installers must be built and signed with ONE temporary CI certificate after build.
# Never run on a real user's machine. Never publish the test installers.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactFolder)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or
    [Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'Upgrade smoke is only allowed on the disposable Windows CI runner.'
}

$root = (Resolve-Path -LiteralPath $ArtifactFolder).Path
$oldSetup = Join-Path $root 'old\DK-Easy-Renamer-0.1.2-x64-SIGNED-PROBE.exe'
$newSetup = Join-Path $root 'new\DK-Easy-Renamer-0.1.3-x64-SIGNED-PROBE.exe'
$cer = Join-Path $root 'DKEasyRenamer-TEST-ONLY.cer'
foreach ($file in @($oldSetup,$newSetup,$cer)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Missing signed upgrade test file: $file"
    }
}

$public = Get-PfxCertificate -FilePath $cer
if ($public.Subject -ne 'CN=DK Easy Renamer Development' -or
    $public.Subject -ne $public.Issuer) {
    throw 'Only the self-signed development identity is allowed for the disposable upgrade test.'
}
foreach ($setup in @($oldSetup,$newSetup)) {
    $signature = Get-AuthenticodeSignature -LiteralPath $setup
    if ($null -eq $signature.SignerCertificate -or
        $signature.SignerCertificate.Thumbprint -ne $public.Thumbprint) {
        throw "The installer is not signed with the matching temporary CI certificate: $setup"
    }
}
$storePath = 'Cert:\LocalMachine\TrustedPeople\' + $public.Thumbprint
if (Test-Path -LiteralPath $storePath) {
    throw 'The disposable CI certificate is unexpectedly trusted before the test.'
}

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer'
$uninstaller = Join-Path $installDir 'unins000.exe'
$userData = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer'
$sentinel = Join-Path $userData 'upgrade-ci-user-data.txt'
if ((Get-AppxPackage -Name 'DKEasyRenamer.Shell') -or (Test-Path -LiteralPath $installDir) -or
    (Test-Path -LiteralPath $sentinel)) {
    throw 'Runner is not clean: existing installation or fixture data found.'
}

function Invoke-Setup([string]$executable) {
    $process = Start-Process -FilePath $executable -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
    try {
        if ($process.ExitCode -ne 0) {
            throw "Installer failed with exit code $($process.ExitCode): $executable"
        }
    }
    finally { $process.Dispose() }
}

function Assert-Version([string]$expected) {
    $packages = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
    if ($packages.Count -ne 1 -or $packages[0].Version.ToString() -ne $expected) {
        throw "Expected exactly one package version $expected; found $($packages.Version -join ',')."
    }
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1') | Out-Null
    $exe = Join-Path $installDir 'DK.EasyRenamer.App.exe'
    $actual = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
    if (-not $actual.StartsWith($expected.Substring(0,5),[StringComparison]::Ordinal)) {
        throw "Installed EXE has unexpected product version: $actual (expected $expected)."
    }
}

try {
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
    foreach ($setup in @($oldSetup,$newSetup)) {
        $status = (Get-AuthenticodeSignature -LiteralPath $setup).Status
        if ($status -ne 'Valid') {
            throw "Signed test setup did not become valid after explicit CI trust: $setup ($status)"
        }
    }

    # Fresh installation of the old build.
    Invoke-Setup $oldSetup
    Assert-Version '0.1.2.0'
    $registryBefore = (Get-ItemProperty 'HKCU:\Software\DKEasyRenamer').ExecutablePath
    if (-not [string]::Equals($registryBefore,(Join-Path $installDir 'DK.EasyRenamer.App.exe'),
        [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The pre-upgrade Explorer launch path is unexpected.'
    }

    # Simulate local user data that must not be deleted by an in-place upgrade.
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    [IO.File]::WriteAllText($sentinel,'preserve-this-user-data')
    $before = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash

    # Reinstall with same Publisher, Package Family Name and certificate.
    Invoke-Setup $newSetup
    Assert-Version '0.1.3.0'
    $registryAfter = (Get-ItemProperty 'HKCU:\Software\DKEasyRenamer').ExecutablePath
    if (-not [string]::Equals($registryAfter,$registryBefore,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'In-place upgrade changed the Explorer launch executable path.'
    }
    if (-not (Test-Path -LiteralPath $sentinel) -or
        (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -ne $before) {
        throw 'The upgrade modified or deleted local user data.'
    }

    # Uninstall must remove the upgraded package and Explorer registration.
    if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        throw 'The upgraded installation has no uninstaller.'
    }
    Invoke-Setup $uninstaller
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null
    if (-not (Test-Path -LiteralPath $sentinel)) {
        throw 'Uninstall unexpectedly removed retained local user data.'
    }
    Write-Host 'CI PASS: signed 0.1.2 -> 0.1.3 in-place upgrade, package/COM registration, user data, uninstall.'
    Write-Host 'This is not a Windows 11 interactive acceptance or public certificate validation.'
}
finally {
    # Safe cleanup on the disposable runner only, even after an assertion fails.
    if (Test-Path -LiteralPath $uninstaller -PathType Leaf) {
        $cleanup = Start-Process -FilePath $uninstaller -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
        $cleanup.Dispose()
    }
    $remaining = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction SilentlyContinue)
    foreach ($pkg in $remaining) {
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $sentinel) {
        Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $storePath) {
        Remove-Item -LiteralPath $storePath -Force -ErrorAction SilentlyContinue
    }
}
