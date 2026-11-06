# Static contract verification for additional Explorer menu commands.
# Does not register COM objects or touch the local Explorer state.
[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
[xml]$xml = Get-Content -LiteralPath (Join-Path $root 'installer\shell\AppxManifest.xml') -Raw
$classes = @($xml.SelectNodes('//*[local-name()="Class"]') | ForEach-Object { $_.GetAttribute('Id') })
$expectedClsids = @('73F9A0E1-982D-4C4E-AB20-987DCA14E930','F7BE1B68-314C-4F75-9F3E-7C3597B42AD1')
if ($classes.Count -ne 2) { throw 'Exactly one file root and one folder root COM class should be registered.' }
foreach ($clsid in $expectedClsids) {
    if ($classes -notcontains $clsid) { throw "Missing registered Explorer COM class $clsid" }
}
$types = @($xml.SelectNodes('//*[local-name()="ItemType"]'))
foreach ($type in @('*','Directory')) {
    $element = @($types | Where-Object { $_.GetAttribute('Type') -eq $type })
    if ($element.Count -ne 1) { throw "Expected one Explorer ItemType $type" }
    $ids = @($element[0].SelectNodes('./*[local-name()="Verb"]') | ForEach-Object { $_.GetAttribute('Clsid') })
    $expected = if ($type -eq '*') { $expectedClsids[0] } else { $expectedClsids[1] }
    if ($ids.Count -ne 1 -or $ids[0] -ne $expected) {
        throw "Expected one context-specific Explorer flyout root verb for $type"
    }
}
$dll = Join-Path $root 'artifacts\t01\native\DK.EasyRenamer.Shell.dll'
if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw "Missing native DLL: $dll" }
$hex = [Convert]::ToHexString([IO.File]::ReadAllBytes($dll))
foreach ($label in @(
    'DK Easy Renamer',
    '파일 이름 변경...',
    '파일 빠른 순번 변경...',
    '파일 빠른 찾기·바꾸기...',
    '폴더 이름 변경...',
    '폴더 빠른 순번 변경...',
    '폴더 빠른 찾기·바꾸기...'
)) {
    $expected = [Convert]::ToHexString([Text.Encoding]::Unicode.GetBytes($label + [char]0))
    if (-not $hex.Contains($expected)) { throw "Missing Korean UTF-16 title in compiled Explorer DLL: $label" }
}
# Ensure the enumerator includes all three actions and the root reports
# ECF_HASSUBCOMMANDS. Static verification does not replace real Explorer UI.
$source = Get-Content -LiteralPath (Join-Path $root 'src\DK.EasyRenamer.Shell\ExplorerCommand.cpp') -Raw
foreach ($contract in @(
    'case 0: kind = CommandKind::Editor',
    'case 1: kind = CommandKind::Sequence',
    'default: kind = CommandKind::Replace',
    'ECF_HASSUBCOMMANDS',
    'ECF_ISDROPDOWN'
)) {
    if (-not $source.Contains($contract)) { throw "Missing native flyout contract: $contract" }
}
Write-Host 'Context menu contract PASS: distinct file/folder COM roots, 3 child actions per root and correct Unicode labels.'
