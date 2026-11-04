# Static contract verification for additional Explorer menu commands.
# Does not register COM objects or touch the local Explorer state.
[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
[xml]$xml = Get-Content -LiteralPath (Join-Path $root 'installer\shell\AppxManifest.xml') -Raw
$classes = @($xml.SelectNodes('//*[local-name()="Class"]') | ForEach-Object { $_.GetAttribute('Id') })
$expectedClsids = @('73F9A0E1-982D-4C4E-AB20-987DCA14E930','A01D3977-7390-4E7A-AB4E-146A28B71F9C')
foreach ($clsid in $expectedClsids) {
    if ($classes -notcontains $clsid) { throw "Missing registered Explorer COM class $clsid" }
}
$types = @($xml.SelectNodes('//*[local-name()="ItemType"]'))
foreach ($type in @('*','Directory')) {
    $element = @($types | Where-Object { $_.GetAttribute('Type') -eq $type })
    if ($element.Count -ne 1) { throw "Expected one Explorer ItemType $type" }
    $ids = @($element[0].SelectNodes('./*[local-name()="Verb"]') | ForEach-Object { $_.GetAttribute('Clsid') })
    if ($ids.Count -ne 2 -or
        $ids[0] -ne $expectedClsids[0] -or
        $ids[1] -ne $expectedClsids[1]) {
        throw "Existing editor verb or new quick group missing/incorrect in $type"
    }
}
$dll = Join-Path $root 'artifacts\t01\native\DK.EasyRenamer.Shell.dll'
if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw "Missing native DLL: $dll" }
$hex = [Convert]::ToHexString([IO.File]::ReadAllBytes($dll))
foreach ($label in @(
    'DK Easy Renamer로 이름 변경',
    'DK Easy Renamer 빠른 작업',
    '빠른 순번 변경...',
    '빠른 찾기·바꾸기...'
)) {
    $expected = [Convert]::ToHexString([Text.Encoding]::Unicode.GetBytes($label + [char]0))
    if (-not $hex.Contains($expected)) { throw "Missing Korean UTF-16 title in compiled Explorer DLL: $label" }
}
Write-Host 'Quick menu contract PASS: old first-level command preserved; quick submenu registered for file/folder; native labels correct.'
