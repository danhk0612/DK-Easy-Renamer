# One-time, opt-in upload of the reusable developer certificate to a protected GitHub environment.
# Never prints PFX bytes/password and never writes them to the repository.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CertificateDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = 'danhk0612/DK-Easy-Renamer'
$environment = 'dev-signing'
$pfx = Join-Path $CertificateDirectory 'DKEasyRenamer-STABLE-DEV.pfx'
$cer = Join-Path $CertificateDirectory 'DKEasyRenamer-STABLE-DEV.cer'
if (-not (Test-Path -LiteralPath $pfx -PathType Leaf) -or
    -not (Test-Path -LiteralPath $cer -PathType Leaf)) {
    throw 'Generate the stable private PFX and public CER first using New-StableDevCertificate.ps1.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI is missing. Install gh and authenticate with gh auth login first.'
}
& gh auth status --hostname github.com | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI authentication failed.' }
$envName = & gh api ("repos/" + $repo + "/environments/" + $environment) --jq .name 2>$null
if ($LASTEXITCODE -ne 0 -or $envName -ne $environment) {
    throw "Create a protected '$environment' environment under repository Settings -> Environments before uploading secrets."
}
$public = Get-PfxCertificate -FilePath $cer
if ($public.Subject -ne 'CN=DK Easy Renamer Development' -or
    $public.NotAfter -le (Get-Date).AddDays(30)) {
    throw 'Public certificate has unexpected publisher or insufficient remaining validity.'
}
Write-Host "Repository: $repo"
Write-Host "Protected environment: $environment"
Write-Host "Pinned public certificate: $($public.Thumbprint)"
$confirmed = Read-Host 'Type YES to upload this private PFX and password as GitHub environment secrets'
if ($confirmed -cne 'YES') { throw 'Secret upload cancelled; no secret values were sent.' }
$password = Read-Host 'Enter the existing private PFX password' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plain = $null
$bytes = $null
$encoded = $null
$private = $null
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $private = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $pfx, $plain, [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
    if (-not $private.HasPrivateKey -or $private.Thumbprint -ne $public.Thumbprint) {
        throw 'Private PFX did not match the public certificate or contained no signing key.'
    }
    $bytes = [IO.File]::ReadAllBytes($pfx)
    $encoded = [Convert]::ToBase64String($bytes)
    $encoded | & gh secret set DK_DEV_SIGNING_PFX_BASE64 --env $environment -R $repo
    if ($LASTEXITCODE -ne 0) { throw 'Failed to upload the encrypted PFX secret.' }
    $plain | & gh secret set DK_DEV_SIGNING_PFX_PASSWORD --env $environment -R $repo
    if ($LASTEXITCODE -ne 0) { throw 'Failed to upload the PFX password secret.' }
    & gh variable set DK_DEV_SIGNING_THUMBPRINT --body $public.Thumbprint --env $environment -R $repo
    if ($LASTEXITCODE -ne 0) { throw 'Failed to pin the public thumbprint.' }
    Write-Host 'Stable signing secrets/variable configured. No private key was added to Git.'
    Write-Host 'Review dev-signing environment protection, then use workflow_dispatch stable_dev_signing=true.'
}
finally {
    if ($null -ne $bytes) { [Array]::Clear($bytes,0,$bytes.Length) }
    if ($null -ne $private) { $private.Dispose() }
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $plain = $null
    $encoded = $null
}
