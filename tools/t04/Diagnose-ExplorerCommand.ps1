# Read-only diagnostics for Windows 11 modern Explorer menu.
[CmdletBinding()]
param([ValidateRange(1,120)][int]$RecentMinutes = 30)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clsid = '73F9A0E1-982D-4C4E-AB20-987DCA14E930'
$since = (Get-Date).AddMinutes(-$RecentMinutes)

Write-Host '=== Windows / account ==='
[pscustomobject]@{
  Version = [Environment]::OSVersion.Version.ToString()
  Is64BitOS = [Environment]::Is64BitOperatingSystem
  Is64BitPowerShell = [Environment]::Is64BitProcess
  Account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
} | Format-List

Write-Host '=== Sparse package / COM registration ==='
$packages = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
if ($packages.Count -ne 1) { Write-Warning "Expected one package; found $($packages.Count)." }
foreach ($pkg in $packages) {
  $pkg | Select-Object Name, PackageFullName, PackageFamilyName, Status, InstallLocation | Format-List
  $manifest = Get-AppxPackageManifest -Package $pkg.PackageFullName
  $xml = $manifest.OuterXml
  [pscustomobject]@{
    HasContextMenu = $xml.Contains('windows.fileExplorerContextMenus')
    HasComServer = $xml.Contains('windows.comServer')
    HasClsid = $xml.Contains($clsid)
    HasFiles = $xml.Contains('Type="*"')
    HasFolders = $xml.Contains('Type="Directory"')
  } | Format-List
  foreach ($class in @($manifest.SelectNodes('//*[local-name()="ComServer"]//*[local-name()="Class"]'))) {
    [pscustomobject]@{
      ComClsid = $class.GetAttribute('Id')
      RelativeDllPath = $class.GetAttribute('Path')
      ThreadingModel = $class.GetAttribute('ThreadingModel')
    } | Format-List
  }
}

Write-Host '=== External installed binaries and permissions ==='
$key = 'HKCU:\Software\DKEasyRenamer'
if (Test-Path -LiteralPath $key) {
  $settings = Get-ItemProperty -LiteralPath $key
  $settings | Select-Object ExecutablePath, IconPath | Format-List
  $exe = [string]$settings.ExecutablePath
  $directory = Split-Path -Parent $exe
  $dll = Join-Path $directory 'DK.EasyRenamer.Shell.dll'
  $msix = Join-Path $directory 'DKEasyRenamer.Shell.msix'
  foreach ($file in @($exe,$dll,$msix)) {
    $exists = Test-Path -LiteralPath $file -PathType Leaf
    [pscustomobject]@{ Path = $file; Exists = $exists } | Format-List
    if ($exists) {
      $sig = Get-AuthenticodeSignature -LiteralPath $file
      [pscustomobject]@{
        SignatureStatus = [string]$sig.Status
        Signer = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '(none)' }
      } | Format-List
    }
  }
  foreach ($path in @($directory,$dll)) {
    if (Test-Path -LiteralPath $path) {
      $acl = Get-Acl -LiteralPath $path
      Write-Host "ACL: $path"
      $acl.Access | Select-Object IdentityReference,FileSystemRights,AccessControlType,IsInherited |
        Format-Table -AutoSize | Out-String | Write-Host
    }
  }
} else {
  Write-Warning 'Per-user HKCU shell settings missing.'
}

Write-Host '=== Recent relevant Windows events ==='
foreach ($name in @('System','Microsoft-Windows-AppModel-Runtime/Admin',
                    'Microsoft-Windows-AppXDeploymentServer/Operational')) {
  $events = @(Get-WinEvent -FilterHashtable @{ LogName=$name; StartTime=$since } -ErrorAction SilentlyContinue)
  $matches = @($events | Where-Object {
    $_.Message -match '73F9A0E1|DKEasyRenamer|DK Easy Renamer|0x80070005|80070005' -or
    ($name -eq 'System' -and $_.ProviderName -like '*DistributedCOM*' -and
      $_.Id -in @(10010,10016))
  } | Select-Object -First 15)
  if ($matches.Count) {
    Write-Host "Log: $name"
    $matches | Select-Object TimeCreated,Id,ProviderName,Message | Format-List |
      Out-String | Write-Host
  }
}
Write-Host 'Read-only inspection complete. A PowerShell COM activation error alone does not prove Explorer activation failed.'
