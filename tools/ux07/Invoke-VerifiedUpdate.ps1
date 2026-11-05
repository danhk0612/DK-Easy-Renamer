# UX-07b installer handoff. Detached helper survives the WPF app being
# closed by Inno Setup. ONLY a publicly signed installer may run.
# No background polling, certificate import, or trust-store modification.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallerPath,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$ExpectedSignerSubject,
    [Parameter(Mandatory)][string]$ExpectedSignerThumbprint,
    [switch]$PreserveShellMenu,
    [switch]$CheckStagingPathOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# The updater creates a fresh 32-hex folder for EACH downloaded installer.
# Never accept an arbitrary caller-supplied directory or follow a reparse point.
$stagingRoot = [IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Updates')).TrimEnd('\')
$installer = [IO.Path]::GetFullPath($InstallerPath)
$folder = [IO.Path]::GetDirectoryName($installer)
$folderName = [IO.Path]::GetFileName($folder)
$expectedFolder = [IO.Path]::Combine($stagingRoot, $folderName)
$filename = [IO.Path]::GetFileName($installer)

if ($folderName -cnotmatch '^[0-9a-f]{32}$' -or
    -not [string]::Equals($folder, $expectedFolder,
        [StringComparison]::OrdinalIgnoreCase) -or
    $filename -cnotmatch '^DK-Easy-Renamer-[0-9]+\.[0-9]+\.[0-9]+-x64-RELEASE\.exe$' -or
    -not [IO.File]::Exists($installer)) {
    throw 'Installer is outside the exact application-owned release staging path.'
}

# Reject link/junction substitution in every mutable part of the staging path.
foreach ($part in @($stagingRoot, $folder, $installer)) {
    $attributes = (Get-Item -LiteralPath $part -Force).Attributes
    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Installer staging cannot contain symbolic links or junctions.'
    }
}

if ($CheckStagingPathOnly) {
    Write-Output 'Staging path is accepted (no signature validation or execution performed).'
    return
}

$verifier = Join-Path $PSScriptRoot 'Validate-PublicInstaller.ps1'
if (-not (Test-Path -LiteralPath $verifier -PathType Leaf)) {
    throw 'Signed installer verification helper is missing.'
}
& $verifier -InstallerPath $installer -ExpectedSha256 $ExpectedSha256 -ExpectedSignerSubject $ExpectedSignerSubject -ExpectedSignerThumbprint $ExpectedSignerThumbprint | Out-Null

$installTask = if ($PreserveShellMenu) { '/TASKS=shellmenu' } else { '/TASKS=' }
# Start-Process -Wait tracks the installer process tree. Waiting in this
# separate PowerShell process survives Setup closing the WPF app.
# The caller never runs Setup before this independent final signature check.
$completed = $false
$child = Start-Process -FilePath $installer -ArgumentList @($installTask) -PassThru -Wait
try {
    $completed = $child.HasExited
    if (-not $completed) { throw 'Installer process tree did not finish.' }
    if ($child.ExitCode -ne 0) {
        throw "Installer exited with a nonzero code: $($child.ExitCode)."
    }
}
finally {
    $child.Dispose()
}

# Cleanup only after confirmed success. Remove only the verified installer
# filename, then remove its GUID directory ONLY when empty. Any unrelated file
# in the stage survives and prevents deleting the directory.
if ($completed) {
    foreach ($part in @($folder, $installer)) {
        if (-not (Test-Path -LiteralPath $part)) {
            throw 'Staged file changed before cleanup.'
        }
        if (((Get-Item -LiteralPath $part -Force).Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Staged file changed into a link; cleanup aborted.'
        }
    }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $ExpectedSha256.ToUpperInvariant()) {
        throw 'Staged installer changed before cleanup; cleanup aborted.'
    }

    Remove-Item -LiteralPath $installer -Force
    if (@(Get-ChildItem -LiteralPath $folder -Force).Count -eq 0) {
        [IO.Directory]::Delete($folder)
    }
}
