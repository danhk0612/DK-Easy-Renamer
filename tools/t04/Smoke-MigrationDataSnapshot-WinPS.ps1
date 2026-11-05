# Verify the standalone snapshot utility with built-in Windows PowerShell 5.1.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'PS5.1 snapshot test runs only in disposable Windows CI.'
}
$root = Join-Path $env:RUNNER_TEMP ('dk-ps51-snapshot-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $root 'source'
$backup = Join-Path $root 'snapshot'
$target = Join-Path $root 'restore'
$script = Join-Path $PSScriptRoot '..\ux07\Invoke-MigrationDataSnapshot.ps1'
$ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $ps)) { throw 'Windows PowerShell 5.1 is missing.' }
New-Item -ItemType Directory -Path $source -Force | Out-Null
$file = Join-Path $source '한글.txt'
[IO.File]::WriteAllText($file,'winps-5.1-original-content')
try {
    Write-Host 'PS5.1 PHASE 1: backup'
    $out = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -Mode Backup -SourceDirectory $source -SnapshotDirectory $backup
    if ($LASTEXITCODE -ne 0 -or ($out | ConvertFrom-Json).Verified -ne $true) {
        throw 'Windows PowerShell backup failed.'
    }

    Write-Host 'PS5.1 PHASE 2: verify and restore to a NEW directory'
    $out = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -Mode Verify -SnapshotDirectory $backup
    if ($LASTEXITCODE -ne 0 -or ($out | ConvertFrom-Json).Files -ne 1) {
        throw 'Windows PowerShell verification failed.'
    }
    $out = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -Mode RestoreToNewDirectory -SnapshotDirectory $backup -RestoreDirectory $target
    if ($LASTEXITCODE -ne 0 -or ($out | ConvertFrom-Json).Verified -ne $true) {
        throw 'Windows PowerShell restore rehearsal failed.'
    }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $target '한글.txt') -Algorithm SHA256).Hash) {
        throw 'Windows PowerShell restored data differs from original.'
    }

    Write-Host 'PS5.1 PHASE 3: existing target must be rejected'
    $null = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -Mode RestoreToNewDirectory -SnapshotDirectory $backup -RestoreDirectory $target 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'Windows PowerShell overwrote an existing restore target.' }
    Write-Host 'PASS: Windows PowerShell 5.1 backup, hash verification, new-folder restore and overwrite refusal.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
