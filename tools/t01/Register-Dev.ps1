# Explicit per-user development registration; not for public distribution.
[CmdletBinding()]
param([switch]$CreateDevCertificate,[switch]$TrustDevCertificate)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dir = Join-Path $root 'artifacts\t01'
$appDir = Join-Path $dir 'app'
$appExe = Join-Path $appDir 'DK.EasyRenamer.App.exe'
$unsigned = Join-Path $dir 'DKEasyRenamer.Shell.unsigned.msix'
if (-not (Test-Path $appExe) -or -not (Test-Path $unsigned)) { throw 'T01 build artifacts are missing.' }
$subject = 'CN=DK Easy Renamer Development'
$cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq $subject -and $_.HasPrivateKey } |
    Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $cert -and $CreateDevCertificate) {
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject -CertStoreLocation 'Cert:\CurrentUser\My'
}
if (-not $cert) { throw 'Developer cert absent. Supply -CreateDevCertificate.' }
if ($TrustDevCertificate) {
    $public = Join-Path $dir 't01-dev-public.cer'
    Export-Certificate -Cert $cert -FilePath $public -Force | Out-Null
    Import-Certificate -FilePath $public -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
}
$sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
$sign = Get-ChildItem $sdk -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sign) { throw 'Windows SDK signtool.exe not found.' }
$signed = Join-Path $dir 'DKEasyRenamer.Shell.dev-signed.msix'
Copy-Item $unsigned $signed -Force
& $sign sign /fd SHA256 /sha1 $cert.Thumbprint /s My $signed
if ($LASTEXITCODE -ne 0) { throw 'MSIX signing failed.' }
Get-AppxPackage -Name DKEasyRenamer.Shell | Remove-AppxPackage
Add-AppxPackage -Path $signed -ExternalLocation $appDir -ErrorAction Stop
$key = 'HKCU:\Software\DKEasyRenamer'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name ExecutablePath -Value $appExe
Set-ItemProperty -Path $key -Name IconPath -Value (Join-Path $appDir 'DK-Easy-Renamer.ico')
Get-AppxPackage -Name DKEasyRenamer.Shell | Select-Object Name,Version,PackageFullName
Write-Host 'Developer command registered; verify first-level Explorer menu on Windows 11.'
