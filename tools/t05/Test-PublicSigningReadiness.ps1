# Verify a proposed publicly trusted DK Easy Renamer release build.
# Read-only, fail-closed: never installs, trusts certificates or publishes an artifact.
# Call only after acquiring a CA-trusted code-signing certificate or approved signing service.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallerPath,
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$AppExecutablePath,
    [Parameter(Mandatory)][string]$ShellDllPath,
    [Parameter(Mandatory)][string]$ExpectedPublisher
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($ExpectedPublisher) -or
    $ExpectedPublisher -eq 'CN=DK Easy Renamer Development') {
    throw 'Public distribution requires an explicit non-development publisher subject.'
}

$targets = [ordered]@{
    Installer = $InstallerPath
    Msix = $PackagePath
    Application = $AppExecutablePath
    Shell = $ShellDllPath
}
$referenceThumbprint = $null
$referenceSubject = $null
foreach ($entry in $targets.GetEnumerator()) {
    $path = (Resolve-Path -LiteralPath $entry.Value -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Not a file: $path"
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction Stop
    $cert = $signature.SignerCertificate
    if ($null -eq $cert) { throw "Missing Authenticode signer on $($entry.Key)." }
    if ([string]::Equals($cert.Subject,$cert.Issuer,
        [StringComparison]::OrdinalIgnoreCase)) {
        throw "Self-signed developer certificates cannot be used for public releases: $($entry.Key)."
    }
    if ($signature.Status -ne 'Valid') {
        throw "The Windows trust chain or signature is not valid for $($entry.Key): $($signature.Status)."
    }
    if (-not [string]::Equals($cert.Subject,$ExpectedPublisher,
        [StringComparison]::OrdinalIgnoreCase)) {
        throw "Signer subject does not match requested publisher for $($entry.Key): $($cert.Subject)."
    }
    if ($null -eq $referenceThumbprint) {
        $referenceThumbprint = $cert.Thumbprint
        $referenceSubject = $cert.Subject
    }
    elseif (-not [string]::Equals($cert.Thumbprint,$referenceThumbprint,
        [StringComparison]::OrdinalIgnoreCase)) {
        throw "This build contains mixed signing certificates (at $($entry.Key))."
    }
}

# A trusted signature alone is insufficient: package identity must use that
# same exact publisher subject or Windows can reject Add-AppxPackage.
Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
try {
    $manifest = $zip.GetEntry('AppxManifest.xml')
    if ($null -eq $manifest) { throw 'MSIX does not contain AppxManifest.xml.' }
    $reader = [IO.StreamReader]::new($manifest.Open())
    try { [xml]$xml = $reader.ReadToEnd() }
    finally { $reader.Dispose() }
    $identity = $xml.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
    if ($null -eq $identity) { throw 'MSIX package identity is missing.' }
    if ($identity.GetAttribute('Name') -ne 'DKEasyRenamer.Shell') {
        throw 'Unexpected package identity name; do not silently replace the Explorer integration.'
    }
    if (-not [string]::Equals($identity.GetAttribute('Publisher'),$referenceSubject,
        [StringComparison]::OrdinalIgnoreCase)) {
        throw 'MSIX manifest publisher and publicly trusted certificate subject differ.'
    }
}
finally { $zip.Dispose() }

Write-Host 'PUBLIC SIGNING STATIC GATE PASSED: four trusted signatures and MSIX publisher agree.'
Write-Host "Publisher: $referenceSubject"
Write-Host "Public certificate thumbprint: $referenceThumbprint"
Write-Host 'This check does not prove SmartScreen reputation, Explorer integration, install/upgrade or Microsoft Store approval.'
