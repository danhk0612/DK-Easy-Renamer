# UX-07g: Retain and verify a previously approved signed Setup + matching MSIX.
# This manual standalone tool NEVER executes files, registers Appx identities,
# imports certificates, installs software, deletes data, or updates trust.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Capture','Verify','StageToNewDirectory')][string]$Mode,
    [Parameter(Mandatory)][string]$ArchiveDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSignerThumbprint,
    [Parameter(Mandatory)][string]$ExpectedSignerSubject,
    [string]$InstallerPath,
    [string]$MsixPath,
    [string]$StageDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$pin = $ExpectedSignerThumbprint.ToUpperInvariant()

function Full-NonRoot([string]$path) {
    $full = [IO.Path]::GetFullPath($path)
    if ([string]::Equals($full,[IO.Path]::GetPathRoot($full),[StringComparison]::OrdinalIgnoreCase)) {
        throw 'A drive root cannot be an archive or stage directory.'
    }
    return $full.TrimEnd('\')
}
function Assert-NotLink([string]$path) {
    if (((Get-Item -LiteralPath $path -Force -ErrorAction Stop).Attributes -band
        [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Symlinks and junctions are not permitted: $path"
    }
}
function Assert-Signer([string]$path) {
    Assert-NotLink $path
    $sig = Get-AuthenticodeSignature -LiteralPath $path
    if ($null -eq $sig -or $sig.Status -ne 'Valid' -or
        $null -eq $sig.SignerCertificate -or
        -not [string]::Equals($sig.SignerCertificate.Thumbprint,$pin,[StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals($sig.SignerCertificate.Subject,$ExpectedSignerSubject,[StringComparison]::Ordinal)) {
        throw "File signature is invalid or different from the externally pinned old signer: $path"
    }
}
function Read-MsixIdentity([string]$path) {
    Add-Type -AssemblyName System.IO.Compression
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $zip.GetEntry('AppxManifest.xml')
        if ($null -eq $entry) { throw 'Signed MSIX lacks AppxManifest.xml.' }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { [xml]$manifest = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    finally { $zip.Dispose() }
    $id = $manifest.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
    if ($null -eq $id -or
        $id.GetAttribute('Name') -cne 'DKEasyRenamer.Shell' -or
        -not [string]::Equals($id.GetAttribute('Publisher'),$ExpectedSignerSubject,[StringComparison]::Ordinal) -or
        $id.GetAttribute('Version') -notmatch '^[0-9]+\.[0-9]+\.[0-9]+\.0$') {
        throw 'MSIX package Name, Publisher or Version does not match the pinned old identity.'
    }
    return $id.GetAttribute('Version')
}
function Read-SignedPair([string]$setup,[string]$msix) {
    if (-not (Test-Path -LiteralPath $setup -PathType Leaf) -or
        -not (Test-Path -LiteralPath $msix -PathType Leaf)) {
        throw 'Both the original signed Setup and the original signed MSIX are required.'
    }
    $setupName = [IO.Path]::GetFileName($setup)
    $versionMatch = [regex]::Match($setupName,
        '^DK-Easy-Renamer-([0-9]+\.[0-9]+\.[0-9]+)-x64-(SIGNED-PROBE|RELEASE)\.exe$')
    if (-not $versionMatch.Success) {
        throw 'Unexpected old Setup filename; reject unsigned or app-only packages.'
    }
    $setupVersion = $versionMatch.Groups[1].Value
    Assert-Signer $setup
    Assert-Signer $msix
    $msixVersion = Read-MsixIdentity $msix
    if ($msixVersion -cne ($setupVersion + '.0')) {
        throw 'Old Setup and signed MSIX have different versions.'
    }
    return [ordered]@{
        InstallerName = $setupName
        Version = $setupVersion
        Publisher = $ExpectedSignerSubject
        Thumbprint = $pin
        InstallerLength = [long](Get-Item -LiteralPath $setup).Length
        InstallerSha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
        MsixLength = [long](Get-Item -LiteralPath $msix).Length
        MsixSha256 = (Get-FileHash -LiteralPath $msix -Algorithm SHA256).Hash
    }
}
function Check-Archive([string]$folder) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw 'Rollback archive folder does not exist.'
    }
    Assert-NotLink $folder
    $manifestFile = Join-Path $folder 'RollbackManifest.json'
    $payload = Join-Path $folder 'payload'
    if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf) -or
        -not (Test-Path -LiteralPath $payload -PathType Container)) {
        throw 'Rollback archive is incomplete.'
    }
    Assert-NotLink $payload
    Assert-NotLink $manifestFile
    $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.SchemaVersion -ne 1 -or $manifest.Kind -cne 'DK-Easy-Renamer-Signed-Rollback' -or
        $manifest.InstallerName -cnotmatch '^DK-Easy-Renamer-[0-9]+\.[0-9]+\.[0-9]+-x64-(SIGNED-PROBE|RELEASE)\.exe$' -or
        -not [string]::Equals([string]$manifest.Thumbprint,$pin,[StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals([string]$manifest.Publisher,$ExpectedSignerSubject,[StringComparison]::Ordinal)) {
        throw 'Rollback manifest is malformed or contradicts the externally pinned signer.'
    }
    $setup = Join-Path $payload $manifest.InstallerName
    $msix = Join-Path $payload 'DKEasyRenamer.Shell.msix'
    $top = @(Get-ChildItem -LiteralPath $folder -Force)
    $items = @(Get-ChildItem -LiteralPath $payload -Force)
    if ($top.Count -ne 2 -or $items.Count -ne 2 -or
        @(Get-ChildItem -LiteralPath $folder -Recurse -Force).Count -ne 4) {
        throw 'Rollback archive contains extra or missing files.'
    }
    $pair = Read-SignedPair $setup $msix
    foreach ($key in @('InstallerName','Version','Publisher','Thumbprint','InstallerLength',
                       'InstallerSha256','MsixLength','MsixSha256')) {
        if (-not [string]::Equals([string]$manifest.$key,[string]$pair[$key],
            [StringComparison]::OrdinalIgnoreCase)) {
            throw "Rollback bytes differ from manifest: $key"
        }
    }
    return [pscustomobject]@{Pair=$pair;Installer=$setup;Msix=$msix}
}

$archive = Full-NonRoot $ArchiveDirectory
if ($Mode -eq 'Capture') {
    if ([string]::IsNullOrWhiteSpace($InstallerPath) -or
        [string]::IsNullOrWhiteSpace($MsixPath)) {
        throw 'Capture requires explicit original Setup and MSIX paths.'
    }
    $setup = [IO.Path]::GetFullPath($InstallerPath)
    $msix = [IO.Path]::GetFullPath($MsixPath)
    if (Test-Path -LiteralPath $archive) { throw 'Archive destination exists; never overwrite.' }
    $parent = [IO.Path]::GetDirectoryName($archive)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw 'Archive parent folder does not exist.'
    }
    Assert-NotLink $parent
    if ($setup.StartsWith($archive + '\',[StringComparison]::OrdinalIgnoreCase) -or
        $msix.StartsWith($archive + '\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Original source binaries may not be inside the new archive.'
    }
    $before = Read-SignedPair $setup $msix
    $payload = Join-Path $archive 'payload'
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    Copy-Item -LiteralPath $setup -Destination (Join-Path $payload $before.InstallerName) -ErrorAction Stop
    Copy-Item -LiteralPath $msix -Destination (Join-Path $payload 'DKEasyRenamer.Shell.msix') -ErrorAction Stop
    # A source modified during copying cannot produce a verified backup.
    $after = Read-SignedPair $setup $msix
    foreach ($key in @('InstallerSha256','MsixSha256','InstallerLength','MsixLength')) {
        if ($before[$key] -ne $after[$key]) {
            throw 'Original signed package changed while the archive was being captured.'
        }
    }
    $meta = [ordered]@{SchemaVersion=1;Kind='DK-Easy-Renamer-Signed-Rollback'}
    foreach ($key in $before.Keys) { $meta[$key] = $before[$key] }
    $meta | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $archive 'RollbackManifest.json') -Encoding UTF8
    $verified = Check-Archive $archive
    [pscustomobject]@{Mode='Capture';Verified=$true;Version=$verified.Pair.Version;Thumbprint=$pin} | ConvertTo-Json -Compress
}
elseif ($Mode -eq 'Verify') {
    $verified = Check-Archive $archive
    [pscustomobject]@{Mode='Verify';Verified=$true;Version=$verified.Pair.Version;Thumbprint=$pin} | ConvertTo-Json -Compress
}
else {
    if ([string]::IsNullOrWhiteSpace($StageDirectory)) { throw 'StageToNewDirectory requires StageDirectory.' }
    $dest = Full-NonRoot $StageDirectory
    if (Test-Path -LiteralPath $dest) { throw 'Recovery stage exists; never overwrite.' }
    if ($dest.StartsWith($archive + '\',[StringComparison]::OrdinalIgnoreCase) -or
        $archive.StartsWith($dest + '\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Recovery stage and archive may not contain each other.'
    }
    $parent = [IO.Path]::GetDirectoryName($dest)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw 'Recovery stage parent does not exist.'
    }
    Assert-NotLink $parent
    $verified = Check-Archive $archive
    New-Item -ItemType Directory -Path $dest | Out-Null
    Copy-Item -LiteralPath $verified.Installer -Destination (Join-Path $dest $verified.Pair.InstallerName)
    Copy-Item -LiteralPath $verified.Msix -Destination (Join-Path $dest 'DKEasyRenamer.Shell.msix')
    $restaged = Read-SignedPair (Join-Path $dest $verified.Pair.InstallerName) (Join-Path $dest 'DKEasyRenamer.Shell.msix')
    foreach ($key in @('InstallerSha256','MsixSha256','InstallerLength','MsixLength')) {
        if ($verified.Pair[$key] -ne $restaged[$key]) {
            throw 'Recovery rehearsal copied altered signed files.'
        }
    }
    [pscustomobject]@{Mode='StageToNewDirectory';Verified=$true;Version=$restaged.Version;Thumbprint=$pin} | ConvertTo-Json -Compress
}
