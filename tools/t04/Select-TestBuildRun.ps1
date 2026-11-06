# Select a completed, successful main CI run matching the exact checked-out Git SHA.
# Input is the JSON document returned by GitHub's Actions runs REST endpoint.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Json,
    [Parameter(Mandatory)][string]$HeadSha
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($HeadSha -notmatch '^[a-fA-F0-9]{40}$') { throw 'Expected a full 40-character Git commit SHA.' }

$payload = ConvertFrom-Json -InputObject $Json
if ($null -eq $payload -or $null -eq $payload.workflow_runs) {
    throw 'GitHub Actions response is missing the workflow_runs list.'
}
$runs = @($payload.workflow_runs)
$matching = @($runs | Where-Object {
    $_.head_sha -eq $HeadSha -and $_.head_branch -eq 'main' -and
    $_.status -eq 'completed' -and $_.conclusion -eq 'success' -and
    $_.event -in @('push','workflow_dispatch') -and
    $_.name -eq 'Windows build and tests'
} | Sort-Object -Property id -Descending)
if ($matching.Count -eq 0) {
    throw "No successful main CI run for commit $HeadSha (inspected $($runs.Count) run records). Check Actions or rerun ci.yml on main."
}
[long]$matching[0].id
