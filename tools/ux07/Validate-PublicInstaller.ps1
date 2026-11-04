# UX-07b: offline verification only. Never download, import certificates or launch the installer.
# Supply expected identity only after a separately approved PUBLIC code-signing policy exists.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedSignerSubject,
    [Parameter(Mandatory = $true)][string]$ExpectedSignerThumbprint
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ExpectedSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'Expected SHA-256 must have exactly 64 hexadecimal characters.'
}
if ($ExpectedSignerThumbprint -notmatch '^[0-9a-fA-F]{40}$' -or
    [string]::IsNullOrWhiteSpace($ExpectedSignerSubject)) {
    throw 'A reviewed public signing identity (subject and thumbprint) is required.'
}
# The existing development identity is NEVER permitted for public updates.
if ($ExpectedSignerSubject -eq 'CN=DK Easy Renamer Development') {
    throw 'Development signing identities cannot authorize a public update.'
}
$file = (Resolve-Path -LiteralPath $InstallerPath -ErrorAction Stop).ProviderPath
if (-not [IO.File]::Exists($file) -or [IO.Path]::GetExtension($file) -cne '.exe') {
    throw 'Expected an existing .exe installer.'
}
$computed = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
if (-not $computed.Equals($ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The installer SHA-256 does not match its approved release digest.'
}

# Get-AuthenticodeSignature uses Windows signature verification; a signer certificate
# without Status=Valid is not sufficient. No trust roots are added or bypassed.
$signature = Get-AuthenticodeSignature -LiteralPath $file
if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate) {
    throw 'The installer does not have a valid trusted Authenticode signature.'
}
$cert = $signature.SignerCertificate
if (-not [string]::Equals($cert.Subject, $ExpectedSignerSubject, [StringComparison]::Ordinal) -or
    -not [string]::Equals($cert.Thumbprint, $ExpectedSignerThumbprint, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The installer signer does not match the approved public publisher.'
}
if ([string]::Equals($cert.Subject, $cert.Issuer, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A self-issued development or untrusted certificate cannot authorize a public update.'
}

Write-Output 'Public installer preflight passed (SHA-256, trusted Authenticode and pinned publisher).'
