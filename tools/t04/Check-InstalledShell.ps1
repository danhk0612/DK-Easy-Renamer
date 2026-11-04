# Read-only Windows 11 inspection after a user explicitly installs a signed T04 probe.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packages = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($packages.Count -ne 1) { throw "Expected one installed DKEasyRenamer.Shell identity; found $($packages.Count)." }

$key = 'HKCU:\Software\DKEasyRenamer'
if (-not (Test-Path -Path $key)) { throw 'Per-user shell launch registry key is missing.' }
$settings = Get-ItemProperty -Path $key -ErrorAction Stop
foreach ($name in @('ExecutablePath','IconPath')) {
    if (-not ($settings.PSObject.Properties.Name -contains $name) -or
        [string]::IsNullOrWhiteSpace([string]$settings.$name)) {
        throw "Missing per-user shell launch setting: $name"
    }
    if (-not (Test-Path -LiteralPath ([string]$settings.$name) -PathType Leaf)) {
        throw "Launch path does not exist: $name = $($settings.$name)"
    }
}
$folder = Split-Path -Parent ([string]$settings.ExecutablePath)
$dll = Join-Path $folder 'DK.EasyRenamer.Shell.dll'
if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw 'Native Explorer COM DLL missing from install folder.' }

$manifest = Get-AppxPackageManifest -Package $packages[0].PackageFullName -ErrorAction Stop
$xml = $manifest.OuterXml
if (-not $xml.Contains('windows.fileExplorerContextMenus') -or
    -not $xml.Contains('73F9A0E1-982D-4C4E-AB20-987DCA14E930')) {
    throw 'Installed package manifest does not contain the expected Explorer context command.'
}
$signatures = @(
    (Get-AuthenticodeSignature -LiteralPath ([string]$settings.ExecutablePath)),
    (Get-AuthenticodeSignature -LiteralPath $dll),
    (Get-AuthenticodeSignature -LiteralPath (Join-Path $folder 'DKEasyRenamer.Shell.msix'))
)
foreach ($signature in $signatures) {
    if ($null -eq $signature.SignerCertificate) {
        throw "Missing digital signature: $($signature.Path)"
    }
}
Write-Host 'Static shell inspection complete. This is NOT evidence that Explorer displays or invokes the menu.'
[pscustomobject]@{
    Package = $packages[0].PackageFullName
    Version = [string]$packages[0].Version
    AppExecutable = [string]$settings.ExecutablePath
    Icon = [string]$settings.IconPath
    NativeDll = $dll
    SignedFiles = @($signatures | ForEach-Object {
        [pscustomobject]@{
            Path = $_.Path
            Status = [string]$_.Status
            Thumbprint = $_.SignerCertificate.Thumbprint
        }
    })
    ExplorerMenuVerifiedByThisScript = $false
}
