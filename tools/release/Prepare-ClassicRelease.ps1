# Keep the public SHA256SUMS limited to actually published release assets.
[CmdletBinding()]
param(
    [string]$InstallerDirectory = (Resolve-Path (Join-Path $PSScriptRoot '..\..\artifacts\t05\installer')).Path
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$dir = (Resolve-Path -LiteralPath $InstallerDirectory).Path
$fileName = 'DK-Easy-Renamer-0.2.0-x64-RELEASE.exe'
$setup = Join-Path $dir $fileName
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw 'Expected public classic installer missing.' }
if ((Get-AuthenticodeSignature -LiteralPath $setup).Status -ne 'NotSigned') {
    throw 'Public unsigned installer unexpectedly has an Authenticode signature.'
}
$expected = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
$stagedSums = Get-Content -LiteralPath (Join-Path $dir 'SHA256SUMS.txt')
if ($stagedSums -notcontains "$expected *$fileName") {
    throw 'Installer did not match the validated T05 staging checksum.'
}
"$expected *$fileName" | Set-Content -LiteralPath (Join-Path $dir 'SHA256SUMS.txt') -Encoding ascii
Write-Host "Ready for release: $fileName / $expected"
