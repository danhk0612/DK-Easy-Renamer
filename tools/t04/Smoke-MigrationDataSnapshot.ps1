# Hermetic snapshot/restore rehearsal. Never touches actual user AppData.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Migration data snapshot smoke must run only on a disposable Windows CI VM.'
}

$root = Join-Path $env:RUNNER_TEMP ('dk-appdata-snapshot-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $root 'fake AppData'
$snapshot = Join-Path $root 'backup'
$restore = Join-Path $root 'restore'
$helper = Join-Path $PSScriptRoot '..\ux07\Invoke-MigrationDataSnapshot.ps1'
New-Item -ItemType Directory -Path $source -Force | Out-Null
function Assert-Rejected([scriptblock]$operation,[string]$reason) {
    $rejected = $false
    try { & $operation | Out-Null }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Unsafe snapshot operation was accepted: $reason" }
}
function Invoke-Mode([string]$mode,[string]$from,[string]$to) {
    if ($mode -eq 'Backup') {
        return (& $helper -Mode Backup -SourceDirectory $from -SnapshotDirectory $to | ConvertFrom-Json)
    }
    if ($mode -eq 'Verify') {
        return (& $helper -Mode Verify -SnapshotDirectory $from | ConvertFrom-Json)
    }
    return (& $helper -Mode RestoreToNewDirectory -SnapshotDirectory $from -RestoreDirectory $to | ConvertFrom-Json)
}
try {
    Write-Host 'PHASE 1: create Unicode, binary, nested and empty-dir disposable fixtures'
    $nested = Join-Path $source '한글\日本語'
    $empty = Join-Path $source 'empty folder'
    New-Item -ItemType Directory -Path $nested,$empty -Force | Out-Null
    $a = Join-Path $source 'user file.txt'
    $b = Join-Path $nested '설정.bin'
    [IO.File]::WriteAllText($a,'preserve this harmless fake user data')
    [IO.File]::WriteAllBytes($b,[byte[]]@(0,1,2,3,0,255,128,13,10))
    $sourceHash = (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash

    Write-Host 'PHASE 2: Backup and Validate must capture exactly source bytes'
    $backupResult = Invoke-Mode 'Backup' $source $snapshot
    if (-not $backupResult.Verified -or $backupResult.Files -ne 2 -or $backupResult.Directories -ne 3) {
        throw 'Snapshot content count does not match fixtures.'
    }
    $verify = Invoke-Mode 'Verify' $snapshot $null
    if (-not $verify.Verified -or $verify.Files -ne 2 -or
        (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash -ne $sourceHash) {
        throw 'Snapshot verification changed source files or failed.'
    }

    Write-Host 'PHASE 3: copy restore ONLY into a new directory and compare hashes'
    $restored = Invoke-Mode 'RestoreToNewDirectory' $snapshot $restore
    if (-not $restored.Verified -or
        (Get-FileHash -LiteralPath (Join-Path $restore 'user file.txt') -Algorithm SHA256).Hash -ne $sourceHash -or
        -not (Test-Path -LiteralPath (Join-Path $restore 'empty folder') -PathType Container) -or
        [Convert]::ToHexString([IO.File]::ReadAllBytes($b)) -ne
        [Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $restore '한글\日本語\설정.bin')))) {
        throw 'Restored disposable data differs from original, or an empty directory was lost.'
    }

    Write-Host 'PHASE 4: existing destination cannot be overwritten'
    Assert-Rejected { & $helper -Mode RestoreToNewDirectory -SnapshotDirectory $snapshot -RestoreDirectory $restore } 'existing restore target'
    Assert-Rejected { & $helper -Mode Backup -SourceDirectory $source -SnapshotDirectory $snapshot } 'existing backup'
    if ((Get-FileHash -LiteralPath (Join-Path $restore 'user file.txt') -Algorithm SHA256).Hash -ne $sourceHash) {
        throw 'A refused operation modified existing restored content.'
    }

    Write-Host 'PHASE 5: corrupted backup must block verify and restore'
    $copy = Join-Path $snapshot 'data\user file.txt'
    [IO.File]::WriteAllText($copy,'tampered contents')
    Assert-Rejected { & $helper -Mode Verify -SnapshotDirectory $snapshot } 'modified backup'
    $newTarget = Join-Path $root 'must-not-restore'
    Assert-Rejected { & $helper -Mode RestoreToNewDirectory -SnapshotDirectory $snapshot -RestoreDirectory $newTarget } 'corrupt backup restore'
    if (Test-Path -LiteralPath $newTarget) { throw 'Invalid backup created a restore destination.' }
    [IO.File]::WriteAllText($copy,'preserve this harmless fake user data')

    Write-Host 'PHASE 6: manifest traversal, duplicate files and unexpected content are rejected'
    $manifestPath = Join-Path $snapshot 'SnapshotManifest.json'
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw
    $manifest = $manifestText | ConvertFrom-Json
    $manifest.Files[0].Path = '..\OUTSIDE.txt'
    $manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Assert-Rejected { & $helper -Mode Verify -SnapshotDirectory $snapshot } 'manifest path traversal'
    Set-Content -LiteralPath $manifestPath -Value $manifestText -Encoding utf8
    $manifest = $manifestText | ConvertFrom-Json
    $manifest.Files = @($manifest.Files) + @($manifest.Files[0])
    $manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Assert-Rejected { & $helper -Mode Verify -SnapshotDirectory $snapshot } 'duplicate file entry'
    Set-Content -LiteralPath $manifestPath -Value $manifestText -Encoding utf8
    $extra = Join-Path $snapshot 'data\UNLISTED-DO-NOT-ACCEPT.txt'
    [IO.File]::WriteAllText($extra,'unexpected')
    Assert-Rejected { & $helper -Mode Verify -SnapshotDirectory $snapshot } 'unlisted content'
    Remove-Item -LiteralPath $extra -Force

    Write-Host 'PHASE 7: snapshot destination cannot be nested in source'
    Assert-Rejected { & $helper -Mode Backup -SourceDirectory $source -SnapshotDirectory (Join-Path $source 'nestedBackup') } 'nested snapshot'
    if (Test-Path -LiteralPath (Join-Path $source 'nestedBackup')) {
        throw 'Rejected nested destination created files in source.'
    }

    Write-Host 'PHASE 8: valid empty source is restored as an empty folder'
    $emptySource = Join-Path $root 'emptySource'
    New-Item -ItemType Directory -Path $emptySource | Out-Null
    $emptyBackup = Join-Path $root 'emptyBackup'
    $emptyRestore = Join-Path $root 'emptyRestore'
    $r = Invoke-Mode 'Backup' $emptySource $emptyBackup
    if (-not $r.Verified -or $r.Files -ne 0) { throw 'Empty backup failed.' }
    $r = Invoke-Mode 'RestoreToNewDirectory' $emptyBackup $emptyRestore
    if (-not $r.Verified -or @(Get-ChildItem -LiteralPath $emptyRestore -Force).Count -ne 0) {
        throw 'Empty restore failed.'
    }

    Write-Host 'PASS: local backup, SHA verified restore to new dir, tamper and overwrite protection.'
    Write-Host 'This test never attempts production migration or restores any real AppData.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
