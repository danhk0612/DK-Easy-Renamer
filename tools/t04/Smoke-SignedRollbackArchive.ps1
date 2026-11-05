# Disposable Windows CI: exercise the REAL archive tool using two signed
# developer-probe binaries from the same certificate, after CI-only trust.
# No actual app install, rollback, certificate import or Appx mutation here.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OldSetup,
    [Parameter(Mandatory)][string]$OldMsix,
    [Parameter(Mandatory)][string]$NewMsix,
    [Parameter(Mandatory)][string]$PinnedSubject,
    [Parameter(Mandatory)][string]$PinnedThumbprint
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Signed rollback archive test may run only on a disposable Windows CI runner.'
}
$work = Join-Path $env:RUNNER_TEMP ('dk-rollback-pair-' + [guid]::NewGuid().ToString('N'))
$archive = Join-Path $work 'backup'
$stage = Join-Path $work 'restaged'
$tool = Join-Path $PSScriptRoot '..\ux07\Invoke-SignedRollbackArchive.ps1'
New-Item -ItemType Directory -Path $work | Out-Null

function Call-Archive([string]$mode,[string]$target,[string]$setup,[string]$msix,[string]$stagePath) {
    $arguments = @{
        Mode = $mode
        ArchiveDirectory = $target
        ExpectedSignerSubject = $PinnedSubject
        ExpectedSignerThumbprint = $PinnedThumbprint
    }
    if ($setup) { $arguments.InstallerPath = $setup }
    if ($msix) { $arguments.MsixPath = $msix }
    if ($stagePath) { $arguments.StageDirectory = $stagePath }
    return (& $tool @arguments | ConvertFrom-Json)
}
function Assert-Rejected([scriptblock]$action,[string]$reason) {
    $blocked = $false
    try { & $action | Out-Null } catch { $blocked = $true }
    if (-not $blocked) { throw "Archive validation incorrectly accepted: $reason" }
}

try {
    Write-Host 'PHASE 1: a pinned trusted signer can archive the matching 0.1.2 pair'
    $saved = Call-Archive 'Capture' $archive $OldSetup $OldMsix ''
    if (-not $saved.Verified -or $saved.Version -ne '0.1.2' -or
        -not (Test-Path -LiteralPath $OldSetup -PathType Leaf)) {
        throw 'Original signed pair was not preserved correctly.'
    }

    Write-Host 'PHASE 2: verified archive can stage exact old bytes only into a new folder'
    $ok = Call-Archive 'Verify' $archive '' '' ''
    $copied = Call-Archive 'StageToNewDirectory' $archive '' '' $stage
    $savedSetup = Join-Path $stage ([IO.Path]::GetFileName($OldSetup))
    $savedMsix = Join-Path $stage 'DKEasyRenamer.Shell.msix'
    if (-not $ok.Verified -or -not $copied.Verified -or
        (Get-FileHash -LiteralPath $savedSetup -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $OldSetup -Algorithm SHA256).Hash -or
        (Get-FileHash -LiteralPath $savedMsix -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $OldMsix -Algorithm SHA256).Hash) {
        throw 'Recovery stage differs from source signed files.'
    }

    Write-Host 'PHASE 3: existing archive/stage and incorrect signer pin are rejected'
    Assert-Rejected { Call-Archive 'Capture' $archive $OldSetup $OldMsix '' } 'existing archive overwrite'
    Assert-Rejected { Call-Archive 'StageToNewDirectory' $archive '' '' $stage } 'existing recovery stage overwrite'
    Assert-Rejected {
        & $tool -Mode Verify -ArchiveDirectory $archive -ExpectedSignerSubject $PinnedSubject -ExpectedSignerThumbprint ('F' * 40)
    } 'mismatched external signer thumbprint'

    Write-Host 'PHASE 4: signed MSIX from a different version must not be paired'
    $wrongVersionArchive = Join-Path $work 'wrong-version'
    Assert-Rejected { Call-Archive 'Capture' $wrongVersionArchive $OldSetup $NewMsix '' } 'signed package version mismatch'
    if (Test-Path -LiteralPath $wrongVersionArchive) {
        throw 'Rejected signed package version created a rollback archive.'
    }

    Write-Host 'PHASE 5: corrupt or additional archive content prevents recovery'
    $badFile = Join-Path $archive 'payload\DKEasyRenamer.Shell.msix'
    $bytes = [IO.File]::ReadAllBytes($badFile)
    [IO.File]::WriteAllBytes($badFile,([byte[]]@(0,1,2,3) + $bytes))
    Assert-Rejected { Call-Archive 'Verify' $archive '' '' '' } 'tampered signed MSIX'
    $notCreated = Join-Path $work 'should-not-stage'
    Assert-Rejected { Call-Archive 'StageToNewDirectory' $archive '' '' $notCreated } 'restoring corrupted archive'
    if (Test-Path -LiteralPath $notCreated) { throw 'Invalid archive was staged.' }
    [IO.File]::WriteAllBytes($badFile,$bytes)

    $extra = Join-Path $archive 'payload\EXTRA.txt'
    [IO.File]::WriteAllText($extra,'not part of the rollback pair')
    Assert-Rejected { Call-Archive 'Verify' $archive '' '' '' } 'unlisted backup content'
    Remove-Item -LiteralPath $extra -Force

    Write-Host 'PHASE 6: unsigned Setup and untrusted filename are rejected'
    $fakeSetup = Join-Path $work 'DK-Easy-Renamer-0.1.2-x64-SIGNED-PROBE.exe'
    [IO.File]::WriteAllText($fakeSetup,'fake unsigned installer')
    Assert-Rejected { Call-Archive 'Capture' (Join-Path $work 'unsigned') $fakeSetup $OldMsix '' } 'unsigned executable'
    $fakeName = Join-Path $work 'DK-Easy-Renamer-0.1.2-x64-APP-ONLY.exe'
    Copy-Item -LiteralPath $OldSetup -Destination $fakeName
    Assert-Rejected { Call-Archive 'Capture' (Join-Path $work 'app-only') $fakeName $OldMsix '' } 'app-only filename'

    Write-Host 'PASS: preserved signed installer/MSIX, exact hashes, external signer pin, safe new-folder staging and tamper refusal.'
    Write-Host 'TEST ONLY. This does not execute rollback, approve a public signer, or modify a real user installation.'
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
