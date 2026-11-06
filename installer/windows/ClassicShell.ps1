# Per-user classic IExplorerCommand registration. Never trusts/imports certificates.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallDir,
    [ValidateSet('Query','Register','Unregister')][string]$Mode = 'Query'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$resolved = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$app = Join-Path $resolved 'DK.EasyRenamer.App.exe'
$dll = Join-Path $resolved 'DK.EasyRenamer.Shell.dll'
$icon = Join-Path $resolved 'DK-Easy-Renamer.ico'
$ownerKey = 'HKCU:\Software\DKEasyRenamer'
$classes = 'HKCU:\Software\Classes'
$fileClass = '{73F9A0E1-982D-4C4E-AB20-987DCA14E930}'
$folderClass = '{F7BE1B68-314C-4F75-9F3E-7C3597B42AD1}'
$verbs = @(
    @{ Key = "$classes\*\shell\DKEasyRenamer"; Class = $fileClass },
    @{ Key = "$classes\Directory\shell\DKEasyRenamer"; Class = $folderClass }
)
$logDir = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Logs'

function Same([string]$a, [string]$b) {
    return [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)
}
function DefaultValue([string]$key) {
    if (-not (Test-Path -LiteralPath $key)) { return '' }
    return [string](Get-Item -LiteralPath $key -ErrorAction Stop).GetValue('','')
}
function NamedValue([string]$key,[string]$name) {
    if (-not (Test-Path -LiteralPath $key)) { return '' }
    return [string](Get-Item -LiteralPath $key -ErrorAction Stop).GetValue($name,'')
}
function Diagnostic([string]$message) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    Add-Content -LiteralPath (Join-Path $logDir 'classic-shell.log') -Value ('[{0}] {1}' -f [DateTime]::Now.ToString('s'),$message) -Encoding UTF8
}
function OwnerPath {
    return NamedValue $ownerKey 'ExecutablePath'
}
function ValidateOwnership {
    $owner = OwnerPath
    if ($owner -and -not (Same $owner $app)) {
        throw "Shell owner belongs to a different installation: $owner"
    }
    foreach ($entry in $verbs) {
        $key = [string]$entry.Key
        $want = [string]$entry.Class
        if ((Test-Path -LiteralPath $key) -and -not (Same (NamedValue $key 'ExplorerCommandHandler') $want)) {
            throw "Unowned Explorer verb detected: $key"
        }
        $inproc = "$classes\CLSID\$want\InprocServer32"
        if ((Test-Path -LiteralPath $inproc) -and -not (Same (DefaultValue $inproc) $dll)) {
            throw "A different DLL owns Explorer COM class: $inproc"
        }
    }
}
function OwnedClassicState {
    if (-not (Same (OwnerPath) $app)) { return $false }
    foreach ($entry in $verbs) {
        $key = [string]$entry.Key
        $want = [string]$entry.Class
        if (-not (Same (NamedValue $key 'ExplorerCommandHandler') $want)) { return $false }
        if (-not (Same (DefaultValue "$classes\CLSID\$want\InprocServer32") $dll)) { return $false }
    }
    return $true
}
function ExistsClassic {
    foreach ($entry in $verbs) {
        $key = [string]$entry.Key
        $want = [string]$entry.Class
        if (Test-Path -LiteralPath $key) { return $true }
        if (Test-Path -LiteralPath "$classes\CLSID\$want\InprocServer32") { return $true }
    }
    return $false
}
function RemoveLegacyPackage {
    $previous = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
    if ($previous.Count -eq 0) { return }
    if ($previous.Count -ne 1 -or -not (Same (OwnerPath) $app)) {
        throw 'Previous MSIX registration does not have an unambiguous matching owner.'
    }
    $pkg = $previous[0]
    if (-not (Same ([string]$pkg.Publisher) 'CN=DK Easy Renamer Development')) {
        throw 'Previous MSIX publisher differs; refusing automatic removal.'
    }
    Diagnostic "Removing owned developer MSIX identity: $($pkg.PackageFullName)"
    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop).Count -ne 0) {
        throw 'Previous MSIX registration remains; classic migration not completed.'
    }
}

try {
    if ($Mode -eq 'Query') {
        try { ValidateOwnership }
        catch { exit 3 }
        if (OwnedClassicState) { exit 0 }
        if (ExistsClassic) { exit 3 }
        exit 1
    }
    ValidateOwnership
    if ($Mode -eq 'Register') {
        foreach ($required in @($app,$dll,$icon)) {
            if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
                throw "Installed app component is missing: $required"
            }
        }
        RemoveLegacyPackage
        foreach ($entry in $verbs) {
            $clsid = [string]$entry.Class
            $inproc = "$classes\CLSID\$clsid\InprocServer32"
            New-Item -Path "$classes\CLSID" -Force | Out-Null
            New-Item -Path "$classes\CLSID\$clsid" -Force | Out-Null
            New-Item -Path $inproc -Force | Out-Null
            Set-Item -LiteralPath $inproc -Value $dll
            New-ItemProperty -LiteralPath $inproc -Name 'ThreadingModel' -PropertyType String -Value 'Apartment' -Force | Out-Null
            $key = [string]$entry.Key
            $parent = Split-Path -Path $key -Parent
            New-Item -Path $parent -Force | Out-Null
            New-Item -Path $key -Force | Out-Null
            New-ItemProperty -LiteralPath $key -Name 'ExplorerCommandHandler' -PropertyType String -Value $clsid -Force | Out-Null
            New-ItemProperty -LiteralPath $key -Name 'MUIVerb' -PropertyType String -Value 'DK Easy Renamer' -Force | Out-Null
            New-ItemProperty -LiteralPath $key -Name 'MultiSelectModel' -PropertyType String -Value 'Player' -Force | Out-Null
            New-ItemProperty -LiteralPath $key -Name 'Icon' -PropertyType String -Value $icon -Force | Out-Null
        }
        New-Item -Path $ownerKey -Force | Out-Null
        New-ItemProperty -LiteralPath $ownerKey -Name 'ExecutablePath' -PropertyType String -Value $app -Force | Out-Null
        New-ItemProperty -LiteralPath $ownerKey -Name 'IconPath' -PropertyType String -Value $icon -Force | Out-Null
        New-ItemProperty -LiteralPath $ownerKey -Name 'IntegrationMode' -PropertyType String -Value 'Classic' -Force | Out-Null
        if (-not (OwnedClassicState)) { throw 'Classic Explorer registration verification failed.' }
        Diagnostic 'Registered user-owned classic Explorer file and folder menu; no certificate used.'
        Write-Host 'Classic Explorer context menu registered for current user.'
    }
    else {
        RemoveLegacyPackage
        foreach ($entry in $verbs) {
            $key = [string]$entry.Key
            $clsid = [string]$entry.Class
            if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
            $classKey = "$classes\CLSID\$clsid"
            if (Test-Path -LiteralPath $classKey) { Remove-Item -LiteralPath $classKey -Recurse -Force }
        }
        if (Test-Path -LiteralPath $ownerKey) {
            $owner = OwnerPath
            if (-not $owner -or -not (Same $owner $app)) {
                throw 'Owner record is invalid; refusing to remove registry entry.'
            }
            Remove-Item -LiteralPath $ownerKey -Recurse -Force
        }
        Diagnostic 'Removed owned classic Explorer menu and any owned developer MSIX registration.'
        Write-Host 'Removed per-user DK Easy Renamer context menu.'
    }
}
catch {
    try { Diagnostic "Classic menu $Mode failed: $($_.ToString())" } catch {}
    Write-Error "Classic Explorer menu $Mode failed: $($_.ToString())"
    exit 4
}
