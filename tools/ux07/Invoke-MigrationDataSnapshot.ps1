# UX-07f: explicit, standalone backup/verify/restore-to-NEW-folder rehearsal.
# Never modify an existing destination or register/remove packages/certificates.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Backup','Verify','RestoreToNewDirectory')]
    [string]$Mode,
    [Parameter(Mandatory)][string]$SnapshotDirectory,
    [string]$SourceDirectory,
    [string]$RestoreDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Normalize-Path([string]$path) {
    return [IO.Path]::GetFullPath($path).TrimEnd('\')
}
function Is-Under([string]$path,[string]$root) {
    return $path.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($path,$root,[StringComparison]::OrdinalIgnoreCase)
}
function Assert-NoReparse([string]$directory) {
    if (((Get-Item -LiteralPath $directory -Force).Attributes -band
         [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse points are not supported in snapshot content: $directory"
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -Recurse -ErrorAction Stop)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point found in snapshot content: $($item.FullName)"
        }
    }
}
function Relative-Path([string]$root,[string]$child) {
    $relative = [IO.Path]::GetRelativePath($root,$child)
    if ([IO.Path]::IsPathFullyQualified($relative) -or
        $relative -eq '.' -or $relative -eq '..' -or
        $relative.StartsWith('..\', [StringComparison]::Ordinal) -or
        $relative.StartsWith('../', [StringComparison]::Ordinal)) {
        throw "Unsafe relative path in snapshot: $relative"
    }
    return $relative
}
function Check-ManifestPath([string]$root,[string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative) -or
        [IO.Path]::IsPathFullyQualified($relative)) {
        throw 'Snapshot manifest has a missing or rooted path.'
    }
    $dest = Normalize-Path (Join-Path $root $relative)
    if (-not (Is-Under $dest $root) -or
        [string]::Equals($dest,$root,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Snapshot manifest attempts path traversal.'
    }
    return $dest
}
function Check-Tree([string]$root,[object[]]$expectedDirs,[object[]]$expectedFiles) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'Snapshot data root is missing.'
    }
    Assert-NoReparse $root
    $seenFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $seenDirs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($relative in $expectedDirs) {
        if ($relative -isnot [string]) { throw 'Invalid directory name in manifest.' }
        $dir = Check-ManifestPath $root $relative
        if (-not $seenDirs.Add($relative) -or -not (Test-Path -LiteralPath $dir -PathType Container)) {
            throw 'Duplicate or missing directory in snapshot.'
        }
    }
    foreach ($file in $expectedFiles) {
        $relative = [string]$file.Path
        $location = Check-ManifestPath $root $relative
        if (-not $seenFiles.Add($relative) -or -not (Test-Path -LiteralPath $location -PathType Leaf)) {
            throw 'Duplicate or missing file in snapshot.'
        }
        $item = Get-Item -LiteralPath $location -Force
        if ($item.Length -ne [long]$file.Length -or
            -not [string]::Equals((Get-FileHash -LiteralPath $location -Algorithm SHA256).Hash,
                [string]$file.Sha256,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'Snapshot file length or SHA-256 does not match its manifest.'
        }
    }
    $actualFiles = @(Get-ChildItem -LiteralPath $root -File -Force -Recurse)
    $actualDirs = @(Get-ChildItem -LiteralPath $root -Directory -Force -Recurse)
    if ($actualFiles.Count -ne $seenFiles.Count -or $actualDirs.Count -ne $seenDirs.Count) {
        throw 'Snapshot data contains unexpected or missing content.'
    }
    foreach ($f in $actualFiles) {
        if (-not $seenFiles.Contains((Relative-Path $root $f.FullName))) {
            throw 'Unexpected file was found in the snapshot data.'
        }
    }
    foreach ($d in $actualDirs) {
        if (-not $seenDirs.Contains((Relative-Path $root $d.FullName))) {
            throw 'Unexpected directory was found in the snapshot data.'
        }
    }
}
function Read-VerifiedManifest([string]$directory) {
    $manifestFile = Join-Path $directory 'SnapshotManifest.json'
    if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) {
        throw 'Snapshot manifest is missing.'
    }
    $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.SchemaVersion -ne 1 -or $manifest.Kind -cne 'DK-Easy-Renamer-AppData' -or
        $null -eq $manifest.Files -or $null -eq $manifest.Directories) {
        throw 'Invalid or incompatible snapshot manifest.'
    }
    $dirs = @($manifest.Directories)
    $files = @($manifest.Files)
    Check-Tree (Join-Path $directory 'data') $dirs $files
    return [pscustomobject]@{ Directories = $dirs; Files = $files }
}

$snapshot = Normalize-Path $SnapshotDirectory
if ($Mode -eq 'Backup') {
    if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
        throw 'Backup requires an explicit -SourceDirectory.'
    }
    $source = Normalize-Path $SourceDirectory
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw 'App data source directory does not exist.'
    }
    if (Test-Path -LiteralPath $snapshot) { throw 'Snapshot directory already exists. Refusing to overwrite.' }
    if ((Is-Under $snapshot $source) -or (Is-Under $source $snapshot)) {
        throw 'Snapshot and source directories must not contain each other.'
    }
    $parent = [IO.Path]::GetDirectoryName($snapshot)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw 'Snapshot destination parent does not exist.'
    }
    Assert-NoReparse $source
    $sourceDirs = @(Get-ChildItem -LiteralPath $source -Directory -Force -Recurse | Sort-Object FullName)
    $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Force -Recurse | Sort-Object FullName)
    # Create a NEW folder only, without deleting anything on failure.
    New-Item -ItemType Directory -Path (Join-Path $snapshot 'data') -Force | Out-Null
    $snapshotData = Join-Path $snapshot 'data'
    $directories = @()
    foreach ($dir in $sourceDirs) {
        $relative = Relative-Path $source $dir.FullName
        New-Item -ItemType Directory -Path (Join-Path $snapshotData $relative) -Force | Out-Null
        $directories += $relative
    }
    $files = @()
    foreach ($file in $sourceFiles) {
        $relative = Relative-Path $source $file.FullName
        $destinationFile = Join-Path $snapshotData $relative
        $destParent = [IO.Path]::GetDirectoryName($destinationFile)
        if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        $before = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -ErrorAction Stop
        $after = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $copied = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash
        if ($before -ne $after -or $before -ne $copied) {
            throw 'Source file changed during backup, or backup bytes differ. Incomplete snapshot is not valid.'
        }
        $files += [ordered]@{
            Path = $relative
            Length = [long]$file.Length
            Sha256 = $before
        }
    }
    $manifest = [ordered]@{
        SchemaVersion = 1
        Kind = 'DK-Easy-Renamer-AppData'
        Directories = @($directories)
        Files = @($files)
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $snapshot 'SnapshotManifest.json') -Encoding UTF8
    $null = Read-VerifiedManifest $snapshot
    [pscustomobject]@{Mode='Backup';Verified=$true;Files=$files.Count;Directories=$directories.Count} | ConvertTo-Json -Compress
}
elseif ($Mode -eq 'Verify') {
    $m = Read-VerifiedManifest $snapshot
    [pscustomobject]@{Mode='Verify';Verified=$true;Files=$m.Files.Count;Directories=$m.Directories.Count} | ConvertTo-Json -Compress
}
else {
    if ([string]::IsNullOrWhiteSpace($RestoreDirectory)) {
        throw 'RestoreToNewDirectory requires an explicit -RestoreDirectory.'
    }
    $target = Normalize-Path $RestoreDirectory
    if (Test-Path -LiteralPath $target) {
        throw 'Restore target already exists. Existing data is never overwritten.'
    }
    if ((Is-Under $target $snapshot) -or (Is-Under $snapshot $target)) {
        throw 'Restore target and snapshot must not contain each other.'
    }
    $parent = [IO.Path]::GetDirectoryName($target)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw 'Restore target parent does not exist.'
    }
    $m = Read-VerifiedManifest $snapshot
    New-Item -ItemType Directory -Path $target | Out-Null
    foreach ($relative in $m.Directories) {
        $null = Check-ManifestPath $target $relative
        New-Item -ItemType Directory -Path (Join-Path $target $relative) -Force | Out-Null
    }
    foreach ($file in $m.Files) {
        $dest = Check-ManifestPath $target ([string]$file.Path)
        $sourceFile = Check-ManifestPath (Join-Path $snapshot 'data') ([string]$file.Path)
        $parent = [IO.Path]::GetDirectoryName($dest)
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourceFile -Destination $dest
    }
    Check-Tree $target $m.Directories $m.Files
    [pscustomobject]@{Mode='RestoreToNewDirectory';Verified=$true;Files=$m.Files.Count;Directories=$m.Directories.Count} | ConvertTo-Json -Compress
}
