# Create a stable development code-signing certificate once. Never commit the PFX.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$target = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if ($target.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or
    $target.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a private output directory OUTSIDE this Git repository.'
}
New-Item -Path $target -ItemType Directory -Force | Out-Null
$pfx = Join-Path $target 'DKEasyRenamer-STABLE-DEV.pfx'
$cer = Join-Path $target 'DKEasyRenamer-STABLE-DEV.cer'
if ((Test-Path -LiteralPath $pfx) -or (Test-Path -LiteralPath $cer)) {
    throw 'A certificate already exists here. Reuse it instead of rotating.'
}
$password = Read-Host 'Enter a strong PFX encryption password; save it securely' -AsSecureString
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=DK Easy Renamer Development' -FriendlyName 'DK Easy Renamer TEST-ONLY stable signing' -CertStoreLocation 'Cert:\CurrentUser\My' -KeyExportPolicy Exportable -NotAfter ((Get-Date).AddYears(2))
if (-not $cert -or -not $cert.HasPrivateKey) { throw 'Certificate generation failed.' }
try {
    Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $password -ChainOption EndEntityCertOnly -ErrorAction Stop | Out-Null
    Export-Certificate -Cert $cert -FilePath $cer -ErrorAction Stop | Out-Null
}
catch {
    if (Test-Path -LiteralPath $pfx) { Remove-Item -LiteralPath $pfx -Force }
    if (Test-Path -LiteralPath $cer) { Remove-Item -LiteralPath $cer -Force }
    throw
}
Write-Host 'TEST-ONLY: the PFX contains a private signing key. Never commit or distribute it.'
[pscustomobject]@{
    CertificateThumbprint = $cert.Thumbprint
    Subject = $cert.Subject
    Expires = $cert.NotAfter
    PrivatePfx = $pfx
    PublicCertificate = $cer
    AutomaticallyTrusted = $false
}
