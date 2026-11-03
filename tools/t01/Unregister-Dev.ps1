# Removes only T01 developer shell registration, not user files.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Get-AppxPackage -Name DKEasyRenamer.Shell | Remove-AppxPackage
Remove-Item -Path 'HKCU:\Software\DKEasyRenamer' -Force -Recurse -ErrorAction SilentlyContinue
Write-Host 'T01 developer registration removed; certificate trust is unchanged.'
