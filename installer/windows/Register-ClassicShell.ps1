# Register a classic ExplorerCommandHandler flyout under HKCU; no MSIX or certificate.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$dir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$exe = Join-Path $dir 'DK.EasyRenamer.App.exe'
$dll = Join-Path $dir 'DK.EasyRenamer.Shell.dll'
$icon = Join-Path $dir 'DK-Easy-Renamer.ico'
$owner = 'HKCU:\Software\DKEasyRenamer'
$classes = 'HKCU:\Software\Classes'
$menuId = 'DK-Easy-Renamer'
$definitions = @(
    @{ Clsid='{73F9A0E1-982D-4C4E-AB20-987DCA14E930}'; Verb="$classes\*\shell\$menuId" },
    @{ Clsid='{F7BE1B68-314C-4F75-9F3E-7C3597B42AD1}'; Verb="$classes\Directory\shell\$menuId" }
)

foreach ($path in @($exe,$dll,$icon)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}
if (Test-Path -LiteralPath $owner) {
    $existing = Get-ItemProperty -LiteralPath $owner -ErrorAction Stop
    if ([string]$existing.ExecutablePath -ine $exe -or
        [string]$existing.ShellMode -ne 'Classic') {
        throw 'Another installation or legacy MSIX registration owns DK Easy Renamer.'
    }
}
foreach ($entry in $definitions) {
    $com = "$classes\CLSID\$($entry.Clsid)\InprocServer32"
    if (Test-Path -LiteralPath $com) {
        $saved = (Get-Item -LiteralPath $com).GetValue('')
        if ([string]$saved -ine $dll) { throw "COM class belongs to a different DLL: $com" }
    }
    if (Test-Path -LiteralPath $entry.Verb) {
        $saved = (Get-ItemProperty -LiteralPath $entry.Verb -Name ExplorerCommandHandler -ErrorAction SilentlyContinue).ExplorerCommandHandler
        if ([string]$saved -ne $entry.Clsid) { throw "Context menu belongs to a different handler: $($entry.Verb)" }
    }
}
foreach ($entry in $definitions) {
    $com = "$classes\CLSID\$($entry.Clsid)\InprocServer32"
    New-Item -Path $com -Force | Out-Null
    Set-Item -LiteralPath $com -Value $dll
    New-ItemProperty -LiteralPath $com -Name ThreadingModel -PropertyType String -Value 'Apartment' -Force | Out-Null
    New-Item -Path $entry.Verb -Force | Out-Null
    New-ItemProperty -LiteralPath $entry.Verb -Name ExplorerCommandHandler -PropertyType String -Value $entry.Clsid -Force | Out-Null
    New-ItemProperty -LiteralPath $entry.Verb -Name Icon -PropertyType String -Value $icon -Force | Out-Null
}
New-Item -Path $owner -Force | Out-Null
New-ItemProperty -LiteralPath $owner -Name ExecutablePath -PropertyType String -Value $exe -Force | Out-Null
New-ItemProperty -LiteralPath $owner -Name IconPath -PropertyType String -Value $icon -Force | Out-Null
New-ItemProperty -LiteralPath $owner -Name ShellMode -PropertyType String -Value 'Classic' -Force | Out-Null
Write-Host 'Registered per-user classic Explorer flyout for files and folders.'
