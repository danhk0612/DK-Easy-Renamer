# Creates a disposable, clearly labeled file/folder test set.
# Does not rename or delete any existing file and never touches non-test folders.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Join-Path ([IO.Path]::GetTempPath()) ('DK-EasyRenamer-T04-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -ErrorAction Stop | Out-Null

$files = [ordered]@{
    'file1.txt'        = 'one'
    'file2.txt'        = 'two'
    'file10.txt'       = 'ten'
    'PHOTO 01.jpg'     = 'sample image placeholder 01 (not a real JPEG)'
    '한글 파일 03.txt' = 'Korean Unicode'
    '日本語 04.txt'    = 'Japanese Unicode'
    'left.txt'         = 'LEFT - for swap tests'
    'right.txt'        = 'RIGHT - for swap tests'
    'Group A\inside.txt' = 'Child of Group A'
    'FolderOLD\child.txt' = 'Child of FolderOLD'
    '빈 폴더\sample.txt' = 'Folder with Korean name'
}
foreach ($name in $files.Keys) {
    $full = Join-Path $root $name
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($full,[string]$files[$name],[Text.UTF8Encoding]::new($false))
}
$manifest = [ordered]@{
    Project = 'DK Easy Renamer'
    Purpose = 'T04 isolated Windows 11 manual test fixtures'
    CreatedUtc = [DateTime]::UtcNow.ToString('O')
    Root = $root
    Items = @($files.Keys)
    Warning = 'Only rename files inside this generated folder. Do not use real documents.'
}
$manifestPath = Join-Path $root '_T04_MANIFEST.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "Created T04 TEST-ONLY directory: $root"
Write-Host 'No existing files were removed or renamed.'
[pscustomobject]@{ Root = $root; Manifest = $manifestPath; FileCount = $files.Count }
