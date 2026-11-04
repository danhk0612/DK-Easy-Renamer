# Build an *unsigned* sparse identity MSIX, with external WPF app and COM DLL.
# T01 default paths are retained for the development probe. T05 may override paths.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ArtifactRoot = '',
    [string]$AppDirectory = '',
    [string]$ManifestFile = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $ArtifactRoot) { $ArtifactRoot = Join-Path $RepositoryRoot 'artifacts\t01' }
if (-not $AppDirectory) { $AppDirectory = Join-Path $ArtifactRoot 'app' }
if (-not $ManifestFile) { $ManifestFile = Join-Path $RepositoryRoot 'installer\shell\AppxManifest.xml' }
$nativeDll = Join-Path $RepositoryRoot 'artifacts\t01\native\DK.EasyRenamer.Shell.dll'
$stage = Join-Path $ArtifactRoot 'package-staging'
$out = Join-Path $ArtifactRoot 'DKEasyRenamer.Shell.unsigned.msix'
if (-not (Test-Path (Join-Path $AppDirectory 'DK.EasyRenamer.App.exe'))) { throw 'App publish output is missing.' }
if (-not (Test-Path $nativeDll)) { throw 'Native x64 COM DLL is missing.' }
if (-not (Test-Path $ManifestFile)) { throw 'Sparse identity manifest is missing.' }
New-Item -ItemType Directory -Path $AppDirectory,$stage,(Join-Path $AppDirectory 'Assets') -Force | Out-Null
Copy-Item $nativeDll (Join-Path $AppDirectory 'DK.EasyRenamer.Shell.dll') -Force
Copy-Item $ManifestFile (Join-Path $stage 'AppxManifest.xml') -Force

# The packaged app uses Square44x44Logo for taskbar grouping under MSIX identity.
# Use the SAME original document/pencil artwork as the EXE/window icon, not a DK text placeholder.
$brandedPng = Join-Path $RepositoryRoot 'assets\icons\DK-Easy-Renamer-256.png'
if (-not (Test-Path -LiteralPath $brandedPng -PathType Leaf)) {
    throw 'Branded PNG missing. Run tools/t03/Generate-Icon.ps1 before sparse packaging.'
}
Add-Type -AssemblyName System.Drawing
$source = [System.Drawing.Image]::FromFile($brandedPng)
try {
    foreach ($entry in @(@('StoreLogo.png',50), @('Square150x150Logo.png',150), @('Square44x44Logo.png',44))) {
        $size = [int]$entry[1]
        $bitmap = [System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.DrawImage($source,
                [System.Drawing.Rectangle]::new(0,0,$size,$size),
                [System.Drawing.Rectangle]::new(0,0,$source.Width,$source.Height),
                [System.Drawing.GraphicsUnit]::Pixel)
            $bitmap.Save((Join-Path (Join-Path $AppDirectory 'Assets') $entry[0]),
                [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
}
finally { $source.Dispose() }
$brandIcon = Join-Path $RepositoryRoot 'assets\icons\DK-Easy-Renamer.ico'
if (-not (Test-Path $brandIcon)) { throw 'T03 branded icon missing. Run Generate-Icon.ps1 first.' }
Copy-Item -LiteralPath $brandIcon -Destination (Join-Path $AppDirectory 'DK-Easy-Renamer.ico') -Force

$sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
$makeAppx = Get-ChildItem $sdk -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $makeAppx) { throw 'Windows SDK makeappx.exe not found.' }
if (Test-Path $out) { Remove-Item $out -Force }
& $makeAppx pack /o /d $stage /nv /p $out
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx failed.' }
Write-Host "Unsigned sparse identity: $out"
Write-Host "External app location: $AppDirectory"
