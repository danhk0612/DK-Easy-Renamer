# Prepare an UNSIGNED APP-ONLY pre-release inspection bundle.
# Never creates a GitHub Release, signs an artifact, or changes Windows trust.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$installerDir = Join-Path $root 'artifacts\t05\installer'
$originalSums = Join-Path $installerDir 'SHA256SUMS.txt'
$previewDir = Join-Path $root 'artifacts\signpath-prep\unsigned-app-only'

$setups = @(Get-ChildItem -LiteralPath $installerDir -Filter 'DK-Easy-Renamer-*-x64-APP-ONLY.exe' -File)
if ($setups.Count -ne 1) {
    throw "Expected exactly one validated unsigned APP-ONLY setup; found $($setups.Count)."
}
$installer = $setups[0]
$versionMatch = [regex]::Match($installer.Name, '^DK-Easy-Renamer-(\d+\.\d+\.\d+)-x64-APP-ONLY\.exe
$signature = Get-AuthenticodeSignature -LiteralPath $installer.FullName
if ($signature.Status -ne 'NotSigned' -or $null -ne $signature.SignerCertificate) {
    throw 'Unsigned preview requires an unsigned installer, not a signed or ambiguous setup.'
}
$hash = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash
$expectedLine = "$hash *$($installer.Name)"
if (-not (Test-Path -LiteralPath $originalSums -PathType Leaf) -or
    (Get-Content -LiteralPath $originalSums) -notcontains $expectedLine) {
    throw 'APP-ONLY setup does not match the existing validated T05 SHA256SUMS.txt.'
}

$sourceCommit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Cannot identify source commit for the release preview.'
}
if (Test-Path -LiteralPath $previewDir) {
    Remove-Item -LiteralPath $previewDir -Recurse -Force
}
New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
Copy-Item -LiteralPath $installer.FullName -Destination $previewDir
$expectedLine | Set-Content -LiteralPath (Join-Path $previewDir 'SHA256SUMS.txt') -Encoding ascii

$notes = @"
# DK Easy Renamer $version — unsigned APP-ONLY (DRAFT, NOT PUBLISHED)

This is a local/CI preview for inspecting a possible first public release.
**This is not a GitHub Release or an approved public download.**

- Windows 11 x64 standalone file/folder renaming application.
- **Unsigned** installer. Windows SmartScreen can warn or block execution.
- **No Windows 11 Explorer right-click integration**; the MSIX extension is not installed.
- No certificate or root trust import is needed for APP-ONLY installation.
- The installer is self-contained and includes MIT/third-party license notices.
- The in-app update installation flow remains disabled pending a trusted public signing identity.

Source: https://github.com/danhk0612/DK-Easy-Renamer
Commit: $sourceCommit
Setup: $($installer.Name)
SHA-256: $hash

The user must approve publication separately. Do not change the filename to
RELEASE.exe or publish the current TEST-ONLY output as a signed product.

SignPath Foundation requires an existing released artifact in the form to be signed.
It is NOT confirmed that publishing APP-ONLY first would satisfy its requirements
for a later signed Explorer-integrated EXE+MSIX release. Ask SignPath before publishing.
"@
$notes | Set-Content -LiteralPath (Join-Path $previewDir 'RELEASE_NOTES_DRAFT.md') -Encoding utf8

$manifest = [ordered]@{
    SchemaVersion = 1
    Product = 'DK Easy Renamer'
    Version = $version
    SourceCommit = $sourceCommit
    Filename = $installer.Name
    Sha256 = $hash
    Signed = $false
    ExplorerContextMenu = $false
    GithubReleasePublished = $false
    SignPathApproved = $false
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $previewDir 'PREVIEW_MANIFEST.json') -Encoding utf8
Write-Host "Unsigned APP-ONLY preview prepared: $previewDir"
Write-Host "Source commit: $sourceCommit; version: $version; SHA-256: $hash"
Write-Warning 'NOT PUBLISHED. No Release, tag, signature, or certificate change was made.'
)
if (-not $versionMatch.Success) {
    throw 'Unexpected APP-ONLY installer name.'
}
$version = $versionMatch.Groups[1].Value
$signature = Get-AuthenticodeSignature -LiteralPath $installer.FullName
if ($signature.Status -ne 'NotSigned' -or $null -ne $signature.SignerCertificate) {
    throw 'Unsigned preview requires an unsigned installer, not a signed or ambiguous setup.'
}
$hash = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash
$expectedLine = "$hash *$($installer.Name)"
if (-not (Test-Path -LiteralPath $originalSums -PathType Leaf) -or
    (Get-Content -LiteralPath $originalSums) -notcontains $expectedLine) {
    throw 'APP-ONLY setup does not match the existing validated T05 SHA256SUMS.txt.'
}

$sourceCommit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Cannot identify source commit for the release preview.'
}
if (Test-Path -LiteralPath $previewDir) {
    Remove-Item -LiteralPath $previewDir -Recurse -Force
}
New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
Copy-Item -LiteralPath $installer.FullName -Destination $previewDir
$expectedLine | Set-Content -LiteralPath (Join-Path $previewDir 'SHA256SUMS.txt') -Encoding ascii

$notes = @"
# DK Easy Renamer $version — unsigned APP-ONLY (DRAFT, NOT PUBLISHED)

This is a local/CI preview for inspecting a possible first public release.
**This is not a GitHub Release or an approved public download.**

- Windows 11 x64 standalone file/folder renaming application.
- **Unsigned** installer. Windows SmartScreen can warn or block execution.
- **No Windows 11 Explorer right-click integration**; the MSIX extension is not installed.
- No certificate or root trust import is needed for APP-ONLY installation.
- The installer is self-contained and includes MIT/third-party license notices.
- The in-app update installation flow remains disabled pending a trusted public signing identity.

Source: https://github.com/danhk0612/DK-Easy-Renamer
Commit: $sourceCommit
Setup: $($installer.Name)
SHA-256: $hash

The user must approve publication separately. Do not change the filename to
RELEASE.exe or publish the current TEST-ONLY output as a signed product.

SignPath Foundation requires an existing released artifact in the form to be signed.
It is NOT confirmed that publishing APP-ONLY first would satisfy its requirements
for a later signed Explorer-integrated EXE+MSIX release. Ask SignPath before publishing.
"@
$notes | Set-Content -LiteralPath (Join-Path $previewDir 'RELEASE_NOTES_DRAFT.md') -Encoding utf8

$manifest = [ordered]@{
    SchemaVersion = 1
    Product = 'DK Easy Renamer'
    Version = $version
    SourceCommit = $sourceCommit
    Filename = $installer.Name
    Sha256 = $hash
    Signed = $false
    ExplorerContextMenu = $false
    GithubReleasePublished = $false
    SignPathApproved = $false
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $previewDir 'PREVIEW_MANIFEST.json') -Encoding utf8
Write-Host "Unsigned APP-ONLY preview prepared: $previewDir"
Write-Host "Source commit: $sourceCommit; version: $version; SHA-256: $hash"
Write-Warning 'NOT PUBLISHED. No Release, tag, signature, or certificate change was made.'
