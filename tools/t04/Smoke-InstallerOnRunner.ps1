# Disposable GitHub-hosted Windows Server 2025 smoke test.
# Never run on a user workstation: installs a temporary self-signed certificate into LocalMachine.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactFolder)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'This privileged smoke test may only run on an ephemeral GitHub-hosted Windows CI runner.'
}
if ([Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'The test runner is older than the minimum supported Windows package build 22000.'
}
$folder = (Resolve-Path -LiteralPath $ArtifactFolder).Path
$setup = @(Get-ChildItem -LiteralPath $folder -Filter 'DK-Easy-Renamer-*-x64-SIGNED-PROBE.exe' -File)
$cer = Join-Path $folder 'DKEasyRenamer-TEST-ONLY.cer'
if ($setup.Count -ne 1 -or -not (Test-Path -LiteralPath $cer -PathType Leaf)) {
    throw 'Expected exactly one signed test installer and its matching public .cer.'
}
$public = Get-PfxCertificate -FilePath $cer
$signer = (Get-AuthenticodeSignature -LiteralPath $setup[0].FullName).SignerCertificate
if ($null -eq $signer -or $public.Thumbprint -ne $signer.Thumbprint) {
    throw 'Certificate thumbprint and installer signer do not match.'
}
$storePath = 'Cert:\LocalMachine\TrustedPeople\' + $public.Thumbprint
$existing = Test-Path -LiteralPath $storePath
if ($existing) { throw 'Unexpected pretrusted test certificate on ephemeral runner.' }
$uninstall = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer\unins000.exe'
try {
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
    Write-Host "Temporary CI trust added only for current ephemeral VM: $($public.Thumbprint)"
    $package = Join-Path (Split-Path -Parent $folder) 'DKEasyRenamer.Shell.msix'
    $signature = Get-AuthenticodeSignature -LiteralPath $package
    Write-Host "Direct MSIX signature: $($signature.Status); thumbprint: $($signature.SignerCertificate.Thumbprint)"
    try { & (Join-Path $PSScriptRoot '..\..\installer\windows\Preflight-Shell.ps1') -PackagePath $package }
    catch { Write-Warning ('Direct preflight: ' + $_.ToString()) }
    $logFile = Join-Path $env:RUNNER_TEMP 'dk-renamer-installer-test.log'
    $install = Start-Process -FilePath $setup[0].FullName -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
    if ($install.ExitCode -ne 0) {
        $p = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Logs\shell-preflight.log'
        if (Test-Path -LiteralPath $p) {
            Write-Host '=== Inno preflight diagnostics ==='
            Get-Content -LiteralPath $p | ForEach-Object { Write-Host $_ }
        }
        $r = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Logs\shell-registration.log'
        if (Test-Path -LiteralPath $r) {
            Write-Host '=== Inno registration diagnostics ==='
            Get-Content -LiteralPath $r | Select-Object -Last 70 | ForEach-Object { Write-Host $_ }
        }
        throw "Inno setup failed with exit code $($install.ExitCode)."
    }
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1')
    Write-Host 'Windows Server 2025 package registration smoke PASS (not Windows 11 UI acceptance).'

    if (-not (Test-Path -LiteralPath $uninstall -PathType Leaf)) { throw 'Inno uninstaller missing.' }
    $remove = Start-Process -FilePath $uninstall -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
    if ($remove.ExitCode -ne 0) { throw "Inno uninstall failed with exit code $($remove.ExitCode)." }
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1')
    Write-Host 'Windows Server 2025 uninstall/package cleanup smoke PASS.'
}
finally {
    # This temporary certificate is not shared with user PCs.
    if (Test-Path -LiteralPath $storePath) {
        Remove-Item -LiteralPath $storePath -Force -ErrorAction SilentlyContinue
    }
}
