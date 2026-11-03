# Generate the app's multi-resolution ICO/PNG from vector-like System.Drawing primitives.
# Windows build tool only; no external icon assets or redistributed fonts.
[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing
$destination = Join-Path $RepositoryRoot 'assets\icons'
New-Item -ItemType Directory -Force $destination | Out-Null

$main = [System.Drawing.Bitmap]::new(256,256)
$graphics = [System.Drawing.Graphics]::FromImage($main)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.Clear([System.Drawing.Color]::Transparent)

$blue = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#2D7BC6'))
$white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$sky = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#87DAF4'))
$darkBluePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#2D7BC6'), 10)
$darkBluePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$darkBluePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$whitePen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 5)

try {
    $shape = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $shape.AddArc(6,6,108,108,180,90)
    $shape.AddArc(142,6,108,108,270,90)
    $shape.AddArc(142,142,108,108,0,90)
    $shape.AddArc(6,142,108,108,90,90)
    $shape.CloseFigure()
    $graphics.FillPath($blue,$shape)
    $shape.Dispose()

    $page = [System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(62,48),
        [System.Drawing.Point]::new(160,48),
        [System.Drawing.Point]::new(190,78),
        [System.Drawing.Point]::new(190,202),
        [System.Drawing.Point]::new(177,215),
        [System.Drawing.Point]::new(62,215),
        [System.Drawing.Point]::new(49,202),
        [System.Drawing.Point]::new(49,61))
    $graphics.FillPolygon($white,$page)
    $graphics.FillPolygon($sky,([System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(160,48),
        [System.Drawing.Point]::new(160,78),
        [System.Drawing.Point]::new(190,78))))
    $graphics.DrawLine($darkBluePen,78,111,151,111)
    $graphics.DrawLine($darkBluePen,78,144,141,144)
    $graphics.DrawLine($darkBluePen,78,177,121,177)

    $saved = $graphics.Save()
    $graphics.TranslateTransform(184,177)
    $graphics.RotateTransform(-43)
    $graphics.FillRectangle($sky,-13,-63,29,110)
    $graphics.DrawRectangle($whitePen,-13,-63,29,110)
    $graphics.FillPolygon($white,([System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(-13,47),
        [System.Drawing.Point]::new(16,47),
        [System.Drawing.Point]::new(1,70))))
    $graphics.FillRectangle($white,-13,-63,29,17)
    $graphics.Restore($saved)

    $main.Save((Join-Path $destination 'DK-Easy-Renamer-256.png'),
        [System.Drawing.Imaging.ImageFormat]::Png)

    # ICO directory with embedded high-quality PNG layers (supported by Windows 11).
    $sizes = @(16,24,32,48,64,128,256)
    $layers = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $layer = [System.Drawing.Bitmap]::new($size,$size)
        $render = [System.Drawing.Graphics]::FromImage($layer)
        try {
            $render.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $render.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $render.DrawImage($main,0,0,$size,$size)
            $stream = [System.IO.MemoryStream]::new()
            try {
                $layer.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
                $layers.Add($stream.ToArray())
            }
            finally { $stream.Dispose() }
        }
        finally { $render.Dispose(); $layer.Dispose() }
    }

    $icoPath = Join-Path $destination 'DK-Easy-Renamer.ico'
    $file = [System.IO.File]::Create($icoPath)
    $writer = [System.IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i=0; $i -lt $sizes.Count; $i++) {
            $size = $sizes[$i]
            $writer.Write([byte]($size % 256))
            $writer.Write([byte]($size % 256))
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$layers[$i].Length)
            $writer.Write([uint32]$offset)
            $offset += $layers[$i].Length
        }
        foreach ($bytes in $layers) { $writer.Write($bytes) }
    }
    finally { $writer.Dispose(); $file.Dispose() }
    Write-Host "Generated: $icoPath"
}
finally {
    $whitePen.Dispose()
    $darkBluePen.Dispose()
    $sky.Dispose()
    $white.Dispose()
    $blue.Dispose()
    $graphics.Dispose()
    $main.Dispose()
}
