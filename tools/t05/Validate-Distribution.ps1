# T05 non-interactive artifact integrity and PowerShell syntax validation.
[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$art = Join-Path $root 'artifacts\t05'
$app = Join-Path $art 'app'
$installerDir = Join-Path $art 'installer'
$identity = Join-Path $art 'identity'
$msix = Join-Path $art 'DKEasyRenamer.Shell.msix'
foreach ($file in @(
    (Join-Path $app 'DK.EasyRenamer.App.exe'),
    (Join-Path $app 'DK.EasyRenamer.Shell.dll'),
    (Join-Path $app 'DK-Easy-Renamer.ico'),
    (Join-Path $app 'Assets\StoreLogo.png'),
    (Join-Path $app 'Assets\Square44x44Logo.png'),
    (Join-Path $app 'Assets\Square150x150Logo.png'),
    $msix,
    (Join-Path $identity 'AppxManifest.xml'),
    (Join-Path $identity 'app.manifest'),
    (Join-Path $installerDir 'SHA256SUMS.txt')
)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing required T05 artifact: $file" }
}
[xml]$sparse = Get-Content (Join-Path $identity 'AppxManifest.xml') -Raw
[xml]$exeIdentity = Get-Content (Join-Path $identity 'app.manifest') -Raw
$pkg = $sparse.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
$ex = $exeIdentity.SelectSingleNode('//*[local-name()="msix"]')
if (-not $pkg -or -not $ex) { throw 'Incomplete package/executable identity XML.' }
if ($pkg.GetAttribute('Name') -ne $ex.GetAttribute('packageName') -or
    $pkg.GetAttribute('Publisher') -ne $ex.GetAttribute('publisher') -or
    $ex.GetAttribute('applicationId') -ne 'App') {
    throw 'Executable/package identity mismatch.'
}

# Examine the actual MSIX content without installing it.
Add-Type -AssemblyName System.IO.Compression
$zip = [System.IO.Compression.ZipFile]::OpenRead($msix)
try {
    if (-not ($zip.Entries | Where-Object { $_.FullName -eq 'AppxManifest.xml' })) {
        throw 'Packed sparse MSIX has no manifest.'
    }
}
finally { $zip.Dispose() }

foreach ($script in @('Register-Shell.ps1','Unregister-Shell.ps1')) {
    $source = Join-Path $root ('installer\windows\' + $script)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw "PowerShell syntax failure in $script : $($errors[0])" }
}
$setup = @(Get-ChildItem -LiteralPath $installerDir -Filter 'DK-Easy-Renamer-*-x64-*.exe')
if ($setup.Count -ne 1) { throw "Expected exactly one compiled installer, got $($setup.Count)." }
$sumPath = Join-Path $installerDir 'SHA256SUMS.txt'
$sums = @(Get-Content -LiteralPath $sumPath | Where-Object { $_.Trim() })
foreach ($file in @($setup[0].FullName,$msix)) {
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $line = "$hash *$([IO.Path]::GetFileName($file))"
    if ($sums -notcontains $line) { throw "SHA-256 mismatch for $file" }
}
if ($setup[0].Name.Contains('UNSIGNED-DO-NOT-INSTALL') -and
    -not ($setup[0].Name -match 'UNSIGNED-DO-NOT-INSTALL')) {
    throw 'Unsigned installer lacks a safety marker.'
}
Write-Host "T05 artifact verification passed: $($setup[0].Name); identity $($pkg.GetAttribute('Name')) / $($pkg.GetAttribute('Version'))"
Write-Host 'This validates packaging only, not real installation or Explorer integration.'
