# Test unsigned classic installer and owned registry cleanup in an isolated Actions VM.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactFolder)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'This integration test only runs on disposable Windows GitHub Actions runners.'
}
$folder = (Resolve-Path -LiteralPath $ArtifactFolder).Path
$installer = @(Get-ChildItem -LiteralPath $folder -Filter 'DK-Easy-Renamer-*-x64-CLASSIC-UNSIGNED.exe' -File)
if ($installer.Count -ne 1) { throw 'Expected one classic unsigned installer.' }
if ((Get-AuthenticodeSignature -LiteralPath $installer[0].FullName).Status -ne 'NotSigned') {
    throw 'Classic distribution must remain unsigned.'
}
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\DK Easy Renamer'
$exe = Join-Path $installDir 'DK.EasyRenamer.App.exe'
$dll = Join-Path $installDir 'DK.EasyRenamer.Shell.dll'
$uninstaller = Join-Path $installDir 'unins000.exe'
$owner = 'HKCU:\Software\DKEasyRenamer'
$classes = 'HKCU:\Software\Classes'
$specs = @(
    @{Cls='{73F9A0E1-982D-4C4E-AB20-987DCA14E930}'; Verb="$classes\*\shell\DK-Easy-Renamer"},
    @{Cls='{F7BE1B68-314C-4F75-9F3E-7C3597B42AD1}'; Verb="$classes\Directory\shell\DK-Easy-Renamer"}
)
if ((Test-Path -LiteralPath $installDir) -or
    (Test-Path -LiteralPath $owner) -or
    @(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count) {
    throw 'Test runner not clean.'
}
function Invoke-Checked([string]$file,[string[]]$args) {
    $p = Start-Process -FilePath $file -ArgumentList $args -PassThru
    try {
        if (-not $p.WaitForExit(120000)) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            throw "Timed out: $file"
        }
        if ($p.ExitCode -ne 0) { throw "$file failed with exit $($p.ExitCode)" }
    } finally { $p.Dispose() }
}
function Check-Registered {
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or
        -not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw 'App or native DLL not installed.' }
    if (@(Get-AppxPackage -Name 'DKEasyRenamer.Shell').Count) {
        throw 'Classic setup registered a signed MSIX unexpectedly.'
    }
    $record = Get-ItemProperty -LiteralPath $owner
    if ($record.ExecutablePath -ine $exe -or $record.ShellMode -ne 'Classic') {
        throw 'Classic owner record mismatch.'
    }
    foreach ($item in $specs) {
        $com = "$classes\CLSID\$($item.Cls)\InprocServer32"
        if ((Get-Item -LiteralPath $com).GetValue('') -ine $dll -or
            (Get-ItemProperty -LiteralPath $item.Verb).ExplorerCommandHandler -ne $item.Cls) {
            throw "COM/verb registration mismatch: $($item.Verb)"
        }
    }
}
function Check-Removed {
    if (Test-Path -LiteralPath $owner) { throw 'Orphan owner record.' }
    foreach ($item in $specs) {
        if ((Test-Path -LiteralPath "$classes\CLSID\$($item.Cls)") -or
            (Test-Path -LiteralPath $item.Verb)) {
            throw 'Orphan classic Explorer registry key.'
        }
    }
}
try {
    # Verify opt-in installer task and per-user COM path.
    Invoke-Checked $installer[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/TASKS=classicmenu')
    Check-Registered
    $query = Join-Path $installDir 'Query-ClassicShell.ps1'
    & $query -InstallDir $installDir
    if ($LASTEXITCODE -ne 0) { throw "Expected registered state 0; got $LASTEXITCODE" }
    # Test the UI toggle's exact scripts, not a duplicate direct registry implementation.
    & (Join-Path $installDir 'Unregister-ClassicShell.ps1') -InstallDir $installDir
    Check-Removed
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Shell toggle accidentally removed the application.' }
    & (Join-Path $installDir 'Register-ClassicShell.ps1') -InstallDir $installDir
    Check-Registered
    Invoke-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Check-Removed
    if (Test-Path -LiteralPath $exe) { throw 'Uninstaller retained application executable.' }

    # Task unchecked must not leave a menu on a fresh installation.
    Invoke-Checked $installer[0].FullName @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/TASKS=!')
    Check-Removed
    Invoke-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Check-Removed
    Write-Host 'PASS: unsigned per-user classic COM menu install, toggle, uninstall and opt-out.'
}
finally {
    if (Test-Path -LiteralPath $uninstaller) {
        $p = Start-Process $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru
        $p.Dispose()
    }
}
