# Hermetic negative/positive staging path tests. No installer execution.
# Safe only on an isolated Windows CI runner; cleans its own test files.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Staging path smoke must run only on the disposable Windows CI VM.'
}

$script = Join-Path $PSScriptRoot 'Invoke-VerifiedUpdate.ps1'
$root = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Updates'
$id = [guid]::NewGuid().ToString('N')
$stage = Join-Path $root $id
$another = Join-Path $env:RUNNER_TEMP ('dk-update-outside-' + [guid]::NewGuid().ToString('N'))
$fileName = 'DK-Easy-Renamer-0.2.0-x64-RELEASE.exe'
$good = Join-Path $stage $fileName
New-Item -ItemType Directory -Path $stage,$another -Force | Out-Null
[IO.File]::WriteAllText($good, 'fake bytes; do not execute')
[IO.File]::WriteAllText((Join-Path $another $fileName), 'unrelated fixture')

$common = @{
    ExpectedSha256 = ('A' * 64)
    ExpectedSignerSubject = 'CN=CI Fake Public (never trusted)'
    ExpectedSignerThumbprint = ('B' * 40)
    CheckStagingPathOnly = $true
}
function Assert-Blocked([string]$candidate,[string]$reason) {
    $rejected = $false
    try {
        & $script @common -InstallerPath $candidate | Out-Null
    }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Unsafe staged path was accepted: $reason" }
}

try {
    & $script @common -InstallerPath $good | Out-Null
    Assert-Blocked (Join-Path $another $fileName) 'outside root'
    Assert-Blocked (Join-Path $root $fileName) 'missing GUID folder'
    $wrongName = Join-Path $stage 'DK-Easy-Renamer-0.2.0-x64-SIGNED-PROBE.exe'
    [IO.File]::WriteAllText($wrongName, 'never run')
    Assert-Blocked $wrongName 'development probe filename'

    $wrongFolder = Join-Path $root ('test-' + $id)
    New-Item -ItemType Directory -Path $wrongFolder | Out-Null
    try {
        $wrongPath = Join-Path $wrongFolder $fileName
        [IO.File]::WriteAllText($wrongPath, 'never run')
        Assert-Blocked $wrongPath 'non-GUID directory'
    }
    finally { Remove-Item -LiteralPath $wrongFolder -Recurse -Force }

    # Path-only mode must never run or alter a fake executable.
    if (-not (Test-Path -LiteralPath $good) -or
        (Get-Content -LiteralPath $good -Raw) -ne 'fake bytes; do not execute') {
        throw 'Path check unexpectedly changed or ran the fixture.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $another $fileName))) {
        throw 'Path check unexpectedly touched an unrelated path.'
    }
    Write-Host 'PASS: GUID-only staging path, invalid/outside paths blocked, no execution or deletion.'
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $another -Recurse -Force -ErrorAction SilentlyContinue
}
