# Inspect a CI test installer without executing it or changing certificate trust.
# Supports Windows PowerShell 5.1 and PowerShell 7.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleDirectory,
    [ValidateSet('AppOnly','Explorer')][string]$Mode = 'AppOnly'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundle = (Resolve-Path -LiteralPath $BundleDirectory -ErrorAction Stop).Path
$nested = Join-Path $bundle 'installer'
$installerDir = if (Test-Path -LiteralPath $nested -PathType Container) { $nested } else { $bundle }
$setups = @(Get-ChildItem -LiteralPath $installerDir -File -Filter 'DK-Easy-Renamer-*-x64-*.exe')
$ending = if ($Mode -eq 'Explorer') { '-SIGNED-PROBE.exe' } else { '-APP-ONLY.exe' }
if ($setups.Count -ne 1 -or -not $setups[0].Name.EndsWith($ending,[StringComparison]::Ordinal)) {
    throw "Expected exactly one $Mode test installer ending in $ending; found $($setups.Count)."
}
$setup = $setups[0]
$sumsPath = Join-Path $installerDir 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $sumsPath -PathType Leaf)) { throw 'Missing SHA256SUMS.txt.' }
$sums = @(Get-Content -LiteralPath $sumsPath -ErrorAction Stop)

function Assert-ExpectedHash([string]$file) {
    $name = [IO.Path]::GetFileName($file)
    $pattern = '^([0-9a-fA-F]{64}) \*' + [regex]::Escape($name) + '$'
    $matches = @($sums | ForEach-Object { [regex]::Match($_.Trim(), $pattern) } |
        Where-Object { $_.Success })
    if ($matches.Count -ne 1) { throw "Missing or duplicate SHA-256 entry: $name" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    if (-not [string]::Equals($matches[0].Groups[1].Value,$actual,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "SHA-256 mismatch: $name"
    }
    return $actual
}

$setupHash = Assert-ExpectedHash $setup.FullName
$certificate = $null
$msix = $null
if ($Mode -eq 'Explorer') {
    $msix = Join-Path $bundle 'DKEasyRenamer.Shell.msix'
    if (-not (Test-Path -LiteralPath $msix -PathType Leaf)) { throw 'Signed MSIX missing.' }
    $null = Assert-ExpectedHash $msix
    $cers = @(Get-ChildItem -LiteralPath $installerDir -File -Filter '*.cer')
    if ($cers.Count -ne 1) { throw "Expected one public test CER; found $($cers.Count)." }
    $certificate = Get-PfxCertificate -FilePath $cers[0].FullName
    if ($certificate.Subject -ne 'CN=DK Easy Renamer Development' -or
        $certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)) {
        throw 'Test certificate has the wrong identity or is outside its validity period.'
    }
    foreach ($file in @($setup.FullName,$msix)) {
        $signature = Get-AuthenticodeSignature -LiteralPath $file
        if ($null -eq $signature.SignerCertificate -or
            $signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
            throw "Signed payload certificate does not match the provided CER: $file"
        }
        if ([string]$signature.Status -notin @('Valid','NotTrusted')) {
            throw "Signed payload failed Authenticode inspection: $file (status $($signature.Status); detail $($signature.StatusMessage))"
        }
    }
}
else {
    $unexpected = @(Get-ChildItem -LiteralPath $installerDir -File -Filter '*.cer')
    if ($unexpected.Count -ne 0) { throw 'An APP-ONLY installer must not include a signing certificate.' }
}

[pscustomobject]@{
    Mode = $Mode
    Installer = $setup.FullName
    Sha256 = $setupHash
    PublicCertificate = if ($null -ne $certificate) { $cers[0].FullName } else { $null }
    CertificateThumbprint = if ($null -ne $certificate) { $certificate.Thumbprint } else { $null }
    Msix = $msix
    AutomaticallyTrusted = $false
    ExecutedOrInstalled = $false
}
