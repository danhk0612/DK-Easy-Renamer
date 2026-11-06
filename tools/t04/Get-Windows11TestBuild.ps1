# Download a test installer built from this exact local main commit.
# No installer execution, certificate trust mutation, or Windows setting changes.
[CmdletBinding()]
param(
    [ValidateSet('AppOnly','Explorer')][string]$Mode = 'AppOnly',
    [long]$RunId = 0
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'Run this test preparation on Windows.' }
$repo = 'danhk0612/DK-Easy-Renamer'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

foreach ($command in @('git','gh')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is required. Install Git and GitHub CLI; sign into gh with 'gh auth login'."
    }
}
$branchName = (& git -C $root branch --show-current)
if ($LASTEXITCODE -ne 0 -or $branchName.Trim() -cne 'main') {
    throw 'Check out main and pull the latest code before preparing a test build.'
}
$head = (& git -C $root rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Could not identify the local Git commit.'
}
$dirty = @(& git -C $root status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) {
    throw 'Tracked Git files have uncommitted changes. Test a clean main checkout instead.'
}

if ($RunId -eq 0) {
    # Query GitHub's REST API by the exact commit SHA. Unlike a generic
    # recent-run listing, this cannot silently omit the requested main build.
    $query = "repos/$repo/actions/runs?branch=main&head_sha=$head&per_page=20"
    $response = & gh api --method GET $query
    if ($LASTEXITCODE -ne 0) { throw 'Unable to query GitHub Actions runs; check gh auth status.' }
    $RunId = [long](& (Join-Path $PSScriptRoot 'Select-TestBuildRun.ps1') -Json ($response -join "`n") -HeadSha $head)
}

$runJson = & gh run view $RunId -R $repo --json databaseId,headSha,headBranch,event,status,conclusion,workflowName
if ($LASTEXITCODE -ne 0) { throw "Could not inspect workflow run $RunId." }
$run = $runJson | ConvertFrom-Json
if ($run.headSha -ne $head -or $run.headBranch -ne 'main' -or
    $run.status -ne 'completed' -or $run.conclusion -ne 'success' -or
    $run.workflowName -ne 'Windows build and tests') {
    throw "Run $RunId is not a successful build of this exact main commit."
}
if ($run.event -notin @('push','workflow_dispatch')) {
    throw 'Only successful main push/manual test workflows are accepted.'
}
$artifact = if ($Mode -eq 'Explorer') {
    't05-DEV-SIGNED-TEST-ONLY-MANUAL-TRUST'
} else {
    't05-UNSIGNED-APP-ONLY-TEST-ONLY'
}
$target = Join-Path $root (Join-Path 'artifacts\windows11-test' (Join-Path ([string]$RunId) $Mode))
if (Test-Path -LiteralPath $target) {
    throw "The target already exists; refusing to overwrite test files: $target"
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
& gh run download $RunId -R $repo --name $artifact --dir $target
if ($LASTEXITCODE -ne 0) { throw "Download failed; inspect and remove incomplete files before retrying: $target" }

$validated = & (Join-Path $PSScriptRoot 'Test-TestBuild.ps1') -BundleDirectory $target -Mode $Mode
Write-Host "Verified test artifact from main commit $head / run $RunId"
Write-Host "Installer: $($validated.Installer)"
if ($Mode -eq 'Explorer') {
    Write-Host "Public test certificate (DO NOT import automatically): $($validated.PublicCertificate)"
    Write-Host "Signer thumbprint: $($validated.CertificateThumbprint)"
    Write-Host 'Explicitly review and trust the matching public CER on an isolated Windows 11 VM before shell installation.'
} else {
    Write-Host 'APP-ONLY: No test certificate or Explorer context-menu registration.'
}
Write-Host 'NOT INSTALLED. Run the verified setup only on an isolated Windows 11 test machine.'
$validated
