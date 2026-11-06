# Remove only this user's owned classic Explorer command registrations.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$dir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$exe = Join-Path $dir 'DK.EasyRenamer.App.exe'
$dll = Join-Path $dir 'DK.EasyRenamer.Shell.dll'
$owner = 'HKCU:\Software\DKEasyRenamer'
$classes = 'HKCU:\Software\Classes'
$menuId = 'DK-Easy-Renamer'
$definitions = @(
    @{ Clsid='{73F9A0E1-982D-4C4E-AB20-987DCA14E930}'; Verb="$classes\*\shell\$menuId" },
    @{ Clsid='{F7BE1B68-314C-4F75-9F3E-7C3597B42AD1}'; Verb="$classes\Directory\shell\$menuId" }
)

$existingEntries = @($definitions | Where-Object {
    (Test-Path -LiteralPath $_.Verb) -or
    (Test-Path -LiteralPath "$classes\CLSID\$($_.Clsid)\InprocServer32")
})
if (-not (Test-Path -LiteralPath $owner)) {
    if ($existingEntries.Count) { throw 'Classic shell entries exist without an ownership record; refusing removal.' }
    exit 0
}
$savedOwner = Get-ItemProperty -LiteralPath $owner -ErrorAction Stop
if ([string]$savedOwner.ExecutablePath -ine $exe -or
    [string]$savedOwner.ShellMode -ne 'Classic') {
    throw 'This installation does not own the classic shell registration.'
}
foreach ($entry in $definitions) {
    $com = "$classes\CLSID\$($entry.Clsid)\InprocServer32"
    if (Test-Path -LiteralPath $com) {
        if ([string](Get-Item -LiteralPath $com).GetValue('') -ine $dll) {
            throw "Unexpected COM DLL owner; refusing removal: $com"
        }
    }
    if (Test-Path -LiteralPath $entry.Verb) {
        $saved = (Get-ItemProperty -LiteralPath $entry.Verb -Name ExplorerCommandHandler -ErrorAction SilentlyContinue).ExplorerCommandHandler
        if ([string]$saved -ne $entry.Clsid) {
            throw "Unexpected context menu owner; refusing removal: $($entry.Verb)"
        }
    }
}
foreach ($entry in $definitions) {
    $comRoot = "$classes\CLSID\$($entry.Clsid)"
    if (Test-Path -LiteralPath $entry.Verb) {
        Remove-Item -LiteralPath $entry.Verb -Recurse -Force
    }
    if (Test-Path -LiteralPath $comRoot) {
        Remove-Item -LiteralPath $comRoot -Recurse -Force
    }
}
Remove-Item -LiteralPath $owner -Recurse -Force
Write-Host 'Removed owned classic Explorer commands; no files or certificates changed.'
