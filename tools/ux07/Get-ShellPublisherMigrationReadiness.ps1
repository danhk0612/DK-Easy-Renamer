# Read-only publisher migration readiness report for a Windows 11 sparse MSIX.
# This is NOT a migrator or a rollback backup. It NEVER registers/unregisters,
# copies data, changes certificate stores, or authorizes installer execution.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallDir,
    [Parameter(Mandatory)][string]$CandidatePackagePath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-ShellIdentity([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "MSIX package is missing: $path"
    }
    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $archive.GetEntry('AppxManifest.xml')
        if ($null -eq $entry) { throw "MSIX manifest is missing: $path" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { [xml]$manifest = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    finally { $archive.Dispose() }

    $id = $manifest.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
    if ($null -eq $id -or
        $id.GetAttribute('Name') -cne 'DKEasyRenamer.Shell' -or
        [string]::IsNullOrWhiteSpace($id.GetAttribute('Publisher')) -or
        [string]::IsNullOrWhiteSpace($id.GetAttribute('Version'))) {
        throw 'Unexpected or incomplete DK Easy Renamer MSIX identity.'
    }
    return [pscustomobject][ordered]@{
        Name = $id.GetAttribute('Name')
        Publisher = $id.GetAttribute('Publisher')
        Version = $id.GetAttribute('Version')
        Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}

$folder = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$executable = Join-Path $folder 'DK.EasyRenamer.App.exe'
$oldPackage = Join-Path $folder 'DKEasyRenamer.Shell.msix'
$ownerKey = 'HKCU:\Software\DKEasyRenamer'
$candidate = Read-ShellIdentity ([IO.Path]::GetFullPath($CandidatePackagePath))

# A metadata report can describe an unsigned fixture; it never treats that
# fixture (or even a valid public signature) as permission to run Setup.
$signature = Get-AuthenticodeSignature -LiteralPath $CandidatePackagePath
$signer = if ($null -ne $signature -and $null -ne $signature.SignerCertificate) {
    $signature.SignerCertificate.Subject
} else { $null }
$signerThumbprint = if ($null -ne $signature -and $null -ne $signature.SignerCertificate) {
    $signature.SignerCertificate.Thumbprint
} else { $null }

$registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
$keyPresent = Test-Path -LiteralPath $ownerKey
$owner = $null
if ($keyPresent) {
    $value = Get-ItemProperty -LiteralPath $ownerKey -Name ExecutablePath -ErrorAction SilentlyContinue
    if ($null -ne $value -and $null -ne $value.ExecutablePath) {
        $owner = [string]$value.ExecutablePath
    }
}

$old = $null
$oldExists = Test-Path -LiteralPath $oldPackage -PathType Leaf
$oldReadError = $null
if ($oldExists) {
    try { $old = Read-ShellIdentity $oldPackage }
    catch { $oldReadError = $_.Exception.Message }
}

$reasons = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    $reasons.Add('installed-executable-missing')
}
if ($registered.Count -gt 1) {
    $reasons.Add('multiple-current-user-registrations')
}
if ($keyPresent -and
    ([string]::IsNullOrWhiteSpace($owner) -or
     -not [string]::Equals($owner,$executable,[StringComparison]::OrdinalIgnoreCase))) {
    $reasons.Add('owner-record-not-owned-by-this-install')
}
if ($registered.Count -eq 1 -and -not $keyPresent) {
    $reasons.Add('registered-package-without-owner-record')
}
if ($registered.Count -eq 1 -and $null -eq $old) {
    $reasons.Add('registered-package-without-readable-installed-msix')
}
if ($null -ne $oldReadError) {
    $reasons.Add('installed-msix-invalid')
}
if ($registered.Count -eq 1 -and $null -ne $old -and
    -not [string]::Equals([string]$registered[0].Publisher, $old.Publisher,
        [StringComparison]::Ordinal)) {
    $reasons.Add('registered-publisher-does-not-match-installed-msix')
}
if ($registered.Count -eq 1 -and
    [string]::IsNullOrWhiteSpace([string]$registered[0].PackageFullName)) {
    $reasons.Add('registered-package-full-name-missing')
}

$decision = if ($reasons.Count -gt 0) {
    'blocked'
} elseif ($registered.Count -eq 0) {
    'no-shell-registration'
} elseif ([string]::Equals([string]$registered[0].Publisher,
                          $candidate.Publisher,[StringComparison]::Ordinal)) {
    'same-publisher'
} else {
    'manual-publisher-migration-required'
}

$requiredRecovery = if ($decision -eq 'manual-publisher-migration-required') {
    @(
        'reviewed-old-installer-and-msix-backup',
        'verified-current-user-data-backup',
        'approved-new-publisher-and-signer',
        'windows-11-failure-and-rollback-acceptance'
    )
} else { @() }

$existingPackageReport = $null
if ($registered.Count -eq 1) {
    $existingPackageReport = [ordered]@{
        PackageFullName = [string]$registered[0].PackageFullName
        Publisher = [string]$registered[0].Publisher
        PackageFamilyName = [string]$registered[0].PackageFamilyName
        Version = [string]$registered[0].Version
    }
}

$report = [ordered]@{
    SchemaVersion = 1
    Decision = $decision
    # This report is never an approval token; there is no -Apply option.
    AutomaticMigrationAuthorized = $false
    InstallDirectory = $folder
    InstalledExecutablePresent = (Test-Path -LiteralPath $executable -PathType Leaf)
    OwnerRecordPresent = $keyPresent
    OwnerExecutablePath = $owner
    ExistingRegistrationCount = $registered.Count
    ExistingPackage = $existingPackageReport
    InstalledMsix = $old
    InstalledMsixReadError = $oldReadError
    CandidateMsix = $candidate
    CandidateSignatureStatus = if ($null -ne $signature) { [string]$signature.Status } else { 'Unknown' }
    CandidateSignerSubject = $signer
    CandidateSignerThumbprint = $signerThumbprint
    RecoveryInputsStillRequired = $requiredRecovery
    BlockReasons = @($reasons.ToArray())
}
$report | ConvertTo-Json -Depth 7 -Compress
