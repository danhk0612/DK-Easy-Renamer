# Rejects automatic Explorer identity replacement when the incoming MSIX has
# a different Publisher. Different publisher => different package family.
# No certificate trust changes, package registration or filesystem mutation.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackagePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    throw 'Incoming shell identity package does not exist.'
}
Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try {
    $entry = $zip.GetEntry('AppxManifest.xml')
    if ($null -eq $entry) { throw 'Incoming MSIX is missing AppxManifest.xml.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { [xml]$manifest = $reader.ReadToEnd() }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

$identity = $manifest.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
if ($null -eq $identity -or
    $identity.GetAttribute('Name') -cne 'DKEasyRenamer.Shell' -or
    [string]::IsNullOrWhiteSpace($identity.GetAttribute('Publisher'))) {
    throw 'Incoming MSIX has an unexpected package name or missing publisher.'
}

$expectedPublisher = $identity.GetAttribute('Publisher')
$registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($registered.Count -gt 1) {
    throw 'Multiple Explorer identity registrations exist. Manual review is required.'
}
foreach ($package in $registered) {
    if ($null -eq $package -or
        -not [string]::Equals([string]$package.Publisher, $expectedPublisher,
            [StringComparison]::Ordinal)) {
        throw 'Existing Explorer MSIX publisher differs from incoming package. Do not silently remove or migrate the previous registration.'
    }
}

Write-Output 'Explorer MSIX publisher transition check passed.'
