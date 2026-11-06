# Regression: Windows PowerShell 5.1 parses GitHub Actions REST run JSON,
# chooses an exact main commit, and excludes failed/PR/other-commit runs.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$head = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$other = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
function New-Run($id, $sha, $branch, $status, $conclusion, $eventName, $name) {
    [pscustomobject]@{
        id = $id
        head_sha = $sha
        head_branch = $branch
        status = $status
        conclusion = $conclusion
        event = $eventName
        name = $name
    }
}
$fixture = [pscustomobject]@{
    total_count = 7
    workflow_runs = @(
        (New-Run 100 $head 'main' 'completed' 'failure' 'push' 'Windows build and tests'),
        (New-Run 101 $other 'main' 'completed' 'success' 'push' 'Windows build and tests'),
        (New-Run 102 $head 'feature' 'completed' 'success' 'pull_request' 'Windows build and tests'),
        (New-Run 103 $head 'main' 'in_progress' $null 'push' 'Windows build and tests'),
        (New-Run 104 $head 'main' 'completed' 'success' 'push' 'Different workflow'),
        (New-Run 105 $head 'main' 'completed' 'success' 'push' 'Windows build and tests'),
        (New-Run 106 $head 'main' 'completed' 'success' 'workflow_dispatch' 'Windows build and tests')
    )
} | ConvertTo-Json -Depth 8
$script = Join-Path $PSScriptRoot 'Select-TestBuildRun.ps1'
$id = & $script -Json $fixture -HeadSha $head
if ($id -ne 106) { throw "Expected latest successful main run 106; found $id" }

$rejected = $false
try { $null = & $script -Json $fixture -HeadSha $other.Replace('b','c') }
catch { $rejected = $true }
if (-not $rejected) { throw 'Non-matching SHA must be rejected.' }

$rejected = $false
try { $null = & $script -Json '{"message":"API error"}' -HeadSha $head }
catch { $rejected = $true }
if (-not $rejected) { throw 'Malformed GitHub API response must be rejected.' }

Write-Host 'T04 exact-main-SHA Actions run discovery PASS (Windows PowerShell 5.1 compatible).'
