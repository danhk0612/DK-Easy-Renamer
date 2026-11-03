# T05: build self-contained Windows x64 app, sparse identity and Inno installer.
# Default: compiler-tested but deliberately NOT INSTALLABLE unsigned CI candidate.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Version = '0.1.0',
    [string]$Publisher = 'CN=DK Easy Renamer Development',
    [string]$CertificateThumbprint = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must have three numeric components, e.g. 0.1.0.' }
if ($Publisher -notmatch '^CN=[^"<>]+$') { throw 'Publisher must be a certificate subject starting CN= and contain no XML quotes.' }

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$art = Join-Path $root 'artifacts\t05'
$app = Join-Path $art 'app'
$identity = Join-Path $art 'identity'
$outDir = Join-Path $art 'installer'
New-Item -ItemType Directory -Path $art,$identity,$outDir -Force | Out-Null
$inAppManifest = Join-Path $root 'src\DK.EasyRenamer.App\app.manifest'
$inMsixManifest = Join-Path $root 'installer\shell\AppxManifest.xml'
$appManifest = Join-Path $identity 'app.manifest'
$msixManifest = Join-Path $identity 'AppxManifest.xml'
$appTemplate = [IO.File]::ReadAllText($inAppManifest)
$msixTemplate = [IO.File]::ReadAllText($inMsixManifest)
$old = 'CN=DK Easy Renamer Development'
if (-not $appTemplate.Contains('publisher="' + $old + '"')) { throw 'App identity template has changed.' }
if (-not $msixTemplate.Contains('Publisher="' + $old + '"')) { throw 'MSIX identity template has changed.' }
[IO.File]::WriteAllText($appManifest,
    $appTemplate.Replace('publisher="' + $old + '"', 'publisher="' + $Publisher + '"'))
[IO.File]::WriteAllText($msixManifest,
    $msixTemplate.Replace('Publisher="' + $old + '"', 'Publisher="' + $Publisher + '"').Replace('Version="0.1.0.0"', 'Version="' + $Version + '.0"'))

$icon = Join-Path $root 'assets\icons\DK-Easy-Renamer.ico'
if (-not (Test-Path -LiteralPath $icon)) {
    & (Join-Path $root 'tools\t03\Generate-Icon.ps1') -RepositoryRoot $root
}
if (-not (Test-Path -LiteralPath $icon)) { throw 'App icon generation failed.' }
$native = Join-Path $root 'artifacts\t01\native\DK.EasyRenamer.Shell.dll'
if (-not (Test-Path -LiteralPath $native)) { throw 'Native x64 DLL not built yet. Run the native CI build first.' }
if (Test-Path -LiteralPath $app) { Remove-Item -LiteralPath $app -Recurse -Force }
& dotnet publish (Join-Path $root 'src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj') -c Release -r win-x64 --self-contained true -o $app "-p:ApplicationManifest=$appManifest"
if ($LASTEXITCODE -ne 0) { throw 'Self-contained win-x64 publish failed.' }

& (Join-Path $root 'tools\t01\Build-SparsePackage.ps1') -RepositoryRoot $root -ArtifactRoot $art -AppDirectory $app -ManifestFile $msixManifest
if (-not $?) { throw 'Sparse identity packaging failed.' }
$unsigned = Join-Path $art 'DKEasyRenamer.Shell.unsigned.msix'
$msix = Join-Path $art 'DKEasyRenamer.Shell.msix'
Copy-Item -LiteralPath $unsigned -Destination $msix -Force

$signed = -not [string]::IsNullOrWhiteSpace($CertificateThumbprint)
$flavor = if ($signed) { 'SIGNED-PROBE' } else { 'UNSIGNED-DO-NOT-INSTALL' }
if ($signed) {
    $cert = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $CertificateThumbprint) -ErrorAction Stop
    if (-not $cert.HasPrivateKey -or $cert.Subject -ne $Publisher) {
        throw 'Signing certificate private key/subject does not match the MSIX Publisher.'
    }
    $sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
    $signTool = Get-ChildItem -LiteralPath $sdk -Directory | Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $signTool) { throw 'Windows SDK signtool.exe not found.' }
    foreach ($file in @((Join-Path $app 'DK.EasyRenamer.App.exe'),(Join-Path $app 'DK.EasyRenamer.Shell.dll'),$msix)) {
        & $signTool sign /fd SHA256 /sha1 $cert.Thumbprint /s My /tr http://timestamp.digicert.com /td SHA256 $file
        if ($LASTEXITCODE -ne 0) { throw "Signing failed: $file" }
    }
}

$compilerCandidates = @(
    (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe'),
    (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 7\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $compiler) {
    $cmd = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($cmd) { $compiler = $cmd.Source }
}
if (-not $compiler) { throw 'Inno Setup ISCC.exe is required to compile the installer.' }
$iss = Join-Path $root 'installer\windows\DK-Easy-Renamer.iss'
$arguments = @("/DPackageDir=$art","/DProductVersion=$Version","/DBuildFlavor=$flavor")
if ($signed) {
    $arguments += '/DSignedBuild=1'
    # Inno's signer signs Setup, uninstall binaries and temporary Setup copies.
    # Use the store certificate thumbprint; no passwords/private keys are passed to ISCC.
    $signerCommand = '"' + $signTool + '" sign /fd SHA256 /sha1 ' + $cert.Thumbprint +
        ' /s My /tr http://timestamp.digicert.com /td SHA256 $f'
    $arguments += ('/Sdkrenamersign=' + $signerCommand)
}
$arguments += $iss
# Keep exactly one current installer in the staging output.
Get-ChildItem -LiteralPath $outDir -Filter 'DK-Easy-Renamer-*-x64-*.exe' -File | Remove-Item -Force
# Pass Inno compiler arguments as discrete native argv values; the SignTool
# command contains quoted Windows SDK paths and must remain a single option.
$info = [System.Diagnostics.ProcessStartInfo]::new($compiler)
$info.UseShellExecute = $false
foreach ($value in $arguments) { [void]$info.ArgumentList.Add([string]$value) }
$process = [System.Diagnostics.Process]::Start($info)
if ($null -eq $process) { throw 'Unable to start Inno Setup compiler.' }
try {
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Inno Setup compilation failed (exit $($process.ExitCode))." }
}
finally { $process.Dispose() }

$installer = Join-Path $outDir "DK-Easy-Renamer-$Version-x64-$flavor.exe"
if (-not (Test-Path -LiteralPath $installer)) { throw 'Expected installer artifact is missing.' }
if ($signed) {
    # SignedUninstaller=yes and SignTool= in the ISS script sign both Setup
    # and uninstall; verify the final Setup has an embedded signature.
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($null -eq $signature.SignerCertificate) {
        throw 'Inno Setup did not sign the installer as requested.'
    }
}
$hashes = @($installer,$msix) | ForEach-Object {
    $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
    "$($hash.Hash) *$([IO.Path]::GetFileName($hash.Path))"
}
$hashes | Set-Content -LiteralPath (Join-Path $outDir 'SHA256SUMS.txt') -Encoding ascii
Write-Host "T05 installer candidate: $installer"
Write-Host "T05 identity package: $msix"
if (-not $signed) {
    Write-Warning 'UNSIGNED: This setup deliberately refuses installation. Do not distribute as a release.'
} else {
    Write-Warning 'SIGNED-PROBE: interactive Windows install, trust, uninstall/upgrade and uninstaller signature are NOT tested.'
}
