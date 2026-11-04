# CI-only: exercise optional shell registration with ONE trusted temporary test
# certificate on an ephemeral Windows Server VM. Unsigned app-only setup itself
# is compile-validated, but its execution on end-user Windows is not asserted here.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactFolder)
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
$package = Join-Path (Split-Path -Parent $folder) 'DKEasyRenamer.Shell.msix'
if ($setup.Count -ne 1 -or -not (Test-Path -LiteralPath $cer -PathType Leaf) -or
    -not (Test-Path -LiteralPath $package -PathType Leaf)) {
    throw 'Signed probe, matching certificate or identity package missing.'
}
$public = Get-PfxCertificate -FilePath $cer
$sign = (Get-AuthenticodeSignature -LiteralPath $setup[0].FullName).SignerCertificate
if ($null -eq $sign -or $sign.Thumbprint -ne $public.Thumbprint) {
    throw 'Setup signer does not match the temporary CI certificate.'
}
$storePath = 'Cert:\LocalMachine\TrustedPeople\' + $public.Thumbprint
if (Test-Path -LiteralPath $storePath) {
    throw 'Test certificate already trusted before setup test.'
}
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer'
$app = Join-Path $installDir 'DK.EasyRenamer.App.exe'
$uninstaller = Join-Path $installDir 'unins000.exe'
if ((Get-AppxPackage -Name 'DKEasyRenamer.Shell') -or (Test-Path -LiteralPath $installDir)) {
    throw 'Runner already has an installation. Refusing to overwrite.'
}

function Invoke-Executable([string]$file,[string[]]$arguments) {
    $setup = [IO.Path]::GetFileName($file) -like 'DK-Easy-Renamer-*-x64-*.exe'
    $log = Join-Path $env:RUNNER_TEMP ('dk-optional-inno-' + [guid]::NewGuid().ToString('N') + '.log')
    if ($setup) { $arguments += ('/LOG="' + $log + '"') }
    Write-Host "START executable: $([IO.Path]::GetFileName($file))"
    $process = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    try {
        if (-not $process.WaitForExit(90000)) {
            Write-Host '=== Running Setup-related processes at timeout ==='
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'DK-Easy-Renamer*' -or $_.Name -like 'powershell*' -or $_.Name -like 'pwsh*' } |
                Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List | Out-String |
                Write-Host
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            throw "Process exceeded 90 seconds: $file"
        }
        if ($process.ExitCode -ne 0) {
            throw "Process returned exit $($process.ExitCode): $file"
        }
        Write-Host "PASS executable: $([IO.Path]::GetFileName($file))"
    }
    finally {
        if ($setup) {
            if (Test-Path -LiteralPath $log) {
                Write-Host '=== Inno Setup log (last 80 lines) ==='
                Get-Content -LiteralPath $log -Tail 80 | ForEach-Object { Write-Host $_ }
            } else { Write-Host 'Inno Setup log was NOT created.' }
        }
        $process.Dispose()
    }
}
function Assert-ShellState([int]$expected) {
    $shell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $query = Join-Path $installDir 'Query-ShellState.ps1'
    $p = Start-Process -FilePath $shell -ArgumentList @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
        '-File',('"'+$query+'"'),'-InstallDir',('"'+$installDir+'"')
    ) -PassThru
    try {
        if (-not $p.WaitForExit(60000)) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            throw 'Shell state check exceeded 60 seconds.'
        }
        if ($p.ExitCode -ne $expected) {
            throw "Expected shell state $expected, got $($p.ExitCode)."
        }
        Write-Host "PASS shell state $expected"
    } finally { $p.Dispose() }
}
function Assert-AppInstalledWithoutShell {
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
        throw 'Standalone app executable missing after setup.'
    }
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count -ne 0) {
        throw 'Explorer MSIX registered despite the task being unchecked.'
    }
    if (Test-Path 'HKCU:\Software\DKEasyRenamer') {
        throw 'Explorer menu registry key unexpectedly created.'
    }
}

try {
    Write-Host 'PHASE 1: untrusted development certificate must FAIL the shell preflight'
    $rejected = $false
    try {
        & (Join-Path $PSScriptRoot '..\..\installer\windows\Preflight-Shell.ps1') -PackagePath $package | Out-Null
    }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Untrusted development MSIX was accepted.' }

    # Trust is granted only on the disposable CI VM. Never import automatically
    # on a real Windows installation.
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null

    Write-Host 'PHASE 2: signed installer, unchecked menu => application only'
    Invoke-Executable $setup[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Assert-AppInstalledWithoutShell
    Assert-ShellState 1

    $running = Start-Process -FilePath $app -PassThru
    try {
        Start-Sleep -Seconds 3
        $running.Refresh()
        if ($running.HasExited) {
            throw "Standalone WPF app exited at startup (code $($running.ExitCode))."
        }
    }
    finally {
        if (-not $running.HasExited) { Stop-Process -Id $running.Id -Force -ErrorAction SilentlyContinue }
        $running.Dispose()
    }
    Invoke-Executable $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null

    Write-Host 'PHASE 3: opt in explicitly to signed context menu'
    Invoke-Executable $setup[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/TASKS=shellmenu')
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1') | Out-Null
    Assert-ShellState 0

    Write-Host 'PHASE 4: remove and restore shell without uninstalling the WPF app'
    & (Join-Path $installDir 'Unregister-Shell.ps1') -InstallDir $installDir | Out-Null
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count -ne 0 -or
        (Test-Path 'HKCU:\Software\DKEasyRenamer')) {
        throw 'Menu removal did not clear the registered package and registry.'
    }
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
        throw 'Menu removal unexpectedly removed the app.'
    }
    Assert-ShellState 1
    & (Join-Path $installDir 'Register-Shell.ps1') -InstallDir $installDir | Out-Null
    & (Join-Path $PSScriptRoot 'Check-InstalledShell.ps1') | Out-Null
    Assert-ShellState 0

    Invoke-Executable $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    & (Join-Path $PSScriptRoot 'Check-RemovedShell.ps1') | Out-Null
    Write-Host 'PASS: untrusted preflight rejected; trusted app-only/shell install, off/on and uninstall.'
    Write-Host 'Unsigned setup execution and Windows 11 interactive UI remain unverified.'
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
