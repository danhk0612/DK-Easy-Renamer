# T05 non-interactive artifact, signed-mode and embedded identity validation.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [ValidateSet('Unsigned','Signed','AppOnly','Classic')][string]$ExpectedMode = 'Unsigned'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$art = Join-Path $root 'artifacts\t05'
$app = Join-Path $art 'app'
$exe = Join-Path $app 'DK.EasyRenamer.App.exe'
$installerDir = Join-Path $art 'installer'
$identity = Join-Path $art 'identity'
$msix = Join-Path $art 'DKEasyRenamer.Shell.msix'
foreach ($file in @(
    $exe, (Join-Path $app 'DK.EasyRenamer.Shell.dll'),
    (Join-Path $app 'DK-Easy-Renamer.ico'),
    (Join-Path $app 'Validate-PublicInstaller.ps1'),
    (Join-Path $app 'Invoke-VerifiedUpdate.ps1'),
    (Join-Path $app 'Assets\StoreLogo.png'),
    (Join-Path $app 'Assets\Square44x44Logo.png'),
    (Join-Path $app 'Assets\Square150x150Logo.png'),
    $msix, (Join-Path $identity 'AppxManifest.xml'),
    (Join-Path $identity 'app.manifest'),
    (Join-Path $installerDir 'SHA256SUMS.txt')
)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing required T05 artifact: $file" }
}
# A packaged WPF app's taskbar glyph comes from the MSIX Square44x44Logo.
# Reject the older placeholder (an opaque blue square with the letters DK).
Add-Type -AssemblyName System.Drawing
foreach ($logo in @('Square44x44Logo.png','Square150x150Logo.png','StoreLogo.png')) {
    $bitmap = [System.Drawing.Bitmap]::new((Join-Path $app ('Assets\' + $logo)))
    try {
        if ($bitmap.GetPixel(0,0).A -ne 0) {
            throw "Taskbar/logo asset is not transparent branded artwork: $logo"
        }
    }
    finally { $bitmap.Dispose() }
}
[xml]$sparse = Get-Content (Join-Path $identity 'AppxManifest.xml') -Raw
[xml]$sourceSxs = Get-Content (Join-Path $identity 'app.manifest') -Raw
$pkg = $sparse.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
$sxsSource = $sourceSxs.SelectSingleNode('//*[local-name()="msix"]')
if (-not $pkg -or ($ExpectedMode -ne 'Classic' -and -not $sxsSource)) { throw 'Incomplete package/executable identity XML.' }

# Extract the actual application manifest embedded in the compiled EXE.
$sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
$mt = Get-ChildItem -LiteralPath $sdk -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\mt.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $mt) { throw 'Windows SDK mt.exe not found for embedded executable manifest verification.' }
$extracted = Join-Path $identity 'extracted-app.manifest'
& $mt "-inputresource:$exe;#1" "-out:$extracted"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $extracted)) {
    throw 'Could not extract embedded application identity manifest.'
}
[xml]$actualSxs = Get-Content -LiteralPath $extracted -Raw
$sxs = $actualSxs.SelectSingleNode('//*[local-name()="msix"]')
if ($ExpectedMode -eq 'Classic') {
    if ($sxs -or $sxsSource) { throw 'Classic release must not embed development MSIX identity.' }
} else {
    if (-not $sxs) { throw 'Compiled EXE is missing its sparse MSIX identity.' }
    foreach ($value in @($sxsSource,$sxs)) {
        if ($pkg.GetAttribute('Name') -ne $value.GetAttribute('packageName') -or
            $pkg.GetAttribute('Publisher') -ne $value.GetAttribute('publisher') -or
            $value.GetAttribute('applicationId') -ne 'App') {
            throw 'Actual embedded executable and sparse package identities differ.'
        }
    }
}

Add-Type -AssemblyName System.IO.Compression
$zip = [System.IO.Compression.ZipFile]::OpenRead($msix)
try {
    $entry = $zip.GetEntry('AppxManifest.xml')
    if ($null -eq $entry) { throw 'Sparse package ZIP does not contain AppxManifest.xml.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { [xml]$packed = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $packedIdentity = $packed.SelectSingleNode('/*[local-name()="Package"]/*[local-name()="Identity"]')
    foreach ($field in @('Name','Publisher','Version','ProcessorArchitecture')) {
        if ($pkg.GetAttribute($field) -ne $packedIdentity.GetAttribute($field)) {
            throw "Packed MSIX identity differs from staging manifest: $field"
        }
    }
    $hasSignature = $null -ne $zip.GetEntry('AppxSignature.p7x')
    if ($ExpectedMode -ne 'Signed' -and $hasSignature) {
        throw 'Unsigned build unexpectedly contains a signed MSIX.'
    }
    if ($ExpectedMode -eq 'Signed' -and -not $hasSignature) {
        throw 'Signed build has no MSIX signature.'
    }
}
finally { $zip.Dispose() }

foreach ($script in @(
    'installer\windows\Register-Shell.ps1',
    'installer\windows\Preflight-Shell.ps1',
    'installer\windows\Test-ShellPublisherTransition.ps1',
    'installer\windows\Unregister-Shell.ps1',
    'installer\windows\Query-ClassicShell.ps1',
    'installer\windows\Register-ClassicShell.ps1',
    'installer\windows\Unregister-ClassicShell.ps1',
    'tools\ux07\Validate-PublicInstaller.ps1',
    'tools\ux07\Invoke-VerifiedUpdate.ps1',
    'tools\t05\Build-Distribution.ps1'
)) {
    $source = Join-Path $root $script
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw "PowerShell syntax failure in $script : $($errors[0])" }
}
$setup = @(Get-ChildItem -LiteralPath $installerDir -Filter 'DK-Easy-Renamer-*-x64-*.exe')
if ($setup.Count -ne 1) { throw "Expected exactly one compiled installer, found $($setup.Count)." }
$expectedSuffix = if ($ExpectedMode -eq 'Unsigned') { '-UNSIGNED-DO-NOT-INSTALL.exe' }
    elseif ($ExpectedMode -eq 'AppOnly') { '-APP-ONLY.exe' }
    elseif ($ExpectedMode -eq 'Classic') { '-RELEASE.exe' }
    else { '-SIGNED-PROBE.exe' }
if (-not $setup[0].Name.EndsWith($expectedSuffix,[StringComparison]::Ordinal)) {
    throw "Installer has the wrong safety mode label: $($setup[0].Name)"
}
$sums = @(Get-Content -LiteralPath (Join-Path $installerDir 'SHA256SUMS.txt') | Where-Object { $_.Trim() })
$checksummed = if ($ExpectedMode -eq 'Classic') { @($setup[0].FullName) } else { @($setup[0].FullName,$msix) }
foreach ($file in $checksummed) {
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $line = "$hash *$([IO.Path]::GetFileName($file))"
    if ($sums -notcontains $line) { throw "SHA-256 mismatch for $file" }
}
Write-Host "T05 package verified: $($setup[0].Name); package identity $($pkg.GetAttribute('Name')) / $($pkg.GetAttribute('Version'))"
Write-Host 'Actual EXE identity, packed MSIX XML (developer modes), signature presence and SHA-256 all checked.'
Write-Host 'Physical installation, Explorer menu, upgrades and uninstall are still UNVERIFIED.'
