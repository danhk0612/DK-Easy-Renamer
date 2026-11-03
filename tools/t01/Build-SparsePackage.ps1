# T01 unsigned developer sparse identity package, not production installer.
[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$artifacts = Join-Path $RepositoryRoot 'artifacts\t01'
$appDir = Join-Path $artifacts 'app'
$dll = Join-Path $artifacts 'native\DK.EasyRenamer.Shell.dll'
$stage = Join-Path $artifacts 'package-staging'
$out = Join-Path $artifacts 'DKEasyRenamer.Shell.unsigned.msix'
if (-not (Test-Path (Join-Path $appDir 'DK.EasyRenamer.App.exe'))) { throw 'App publish output is missing.' }
if (-not (Test-Path $dll)) { throw 'Native x64 COM DLL is missing.' }
New-Item -ItemType Directory -Path $appDir,$stage,(Join-Path $appDir 'Assets') -Force | Out-Null
Copy-Item $dll (Join-Path $appDir 'DK.EasyRenamer.Shell.dll') -Force
Copy-Item (Join-Path $RepositoryRoot 'installer\shell\AppxManifest.xml') (Join-Path $stage 'AppxManifest.xml') -Force

# Lightweight temporary T01 blue artwork. T03 owns the final icon.
Add-Type -AssemblyName System.Drawing
foreach ($entry in @(@('StoreLogo.png',50), @('Square150x150Logo.png',150), @('Square44x44Logo.png',44))) {
    $size = [int]$entry[1]
    $bmp = [System.Drawing.Bitmap]::new($size,$size)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#2D7BC6'))
        $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $font = [System.Drawing.Font]::new('Segoe UI',[single]($size*.32),[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
        try {
            $graphics.DrawString('DK',$font,$brush,[single]($size*.1),[single]($size*.23))
            $bmp.Save((Join-Path (Join-Path $appDir 'Assets') $entry[0]),[System.Drawing.Imaging.ImageFormat]::Png)
            if ($size -eq 44) {
                $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
                $s = [System.IO.File]::Create((Join-Path $appDir 'DK-Easy-Renamer.ico'))
                try { $icon.Save($s) } finally { $s.Dispose(); $icon.Dispose() }
            }
        }
        finally { $font.Dispose(); $brush.Dispose() }
    }
    finally { $graphics.Dispose(); $bmp.Dispose() }
}
$sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
$makeAppx = Get-ChildItem $sdk -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $makeAppx) { throw 'Windows SDK makeappx.exe not found.' }
if (Test-Path $out) { Remove-Item $out -Force }
& $makeAppx pack /o /d $stage /nv /p $out
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx failed.' }
Write-Host "Unsigned developer package: $out"
Write-Host "External app location: $appDir"
