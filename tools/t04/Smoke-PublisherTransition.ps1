# Hermetic Windows CI check for the publisher-family guard.
# All MSIX archives here are fake unsigned ZIP fixtures; never installed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Run this test only in an isolated Windows CI runner.'
}

Add-Type -AssemblyName System.IO.Compression
$work = Join-Path $env:RUNNER_TEMP ('dk-publisher-guard-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $work 'contents'
$installDir = Join-Path $work 'app'
New-Item -ItemType Directory -Path $source,$installDir -Force | Out-Null
$guard = Join-Path $PSScriptRoot '..\..\installer\windows\Test-ShellPublisherTransition.ps1'
$preflight = Join-Path $PSScriptRoot '..\..\installer\windows\Preflight-Shell.ps1'
$register = Join-Path $PSScriptRoot '..\..\installer\windows\Register-Shell.ps1'
$script:fakeRegistered = @()
$script:removed = 0
$script:signatureCalls = 0

function Get-AppxPackage {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -cne 'DKEasyRenamer.Shell') { throw 'Wrong fake package name.' }
    return $script:fakeRegistered
}
function Get-AuthenticodeSignature {
    [CmdletBinding()]
    param([string]$LiteralPath)
    $script:signatureCalls++
    return [pscustomobject]@{
        Status = 'Valid'
        SignerCertificate = [pscustomobject]@{
            Subject = 'CN=Future Public Signer'
            Issuer = 'CN=Disposable Test Root'
            Thumbprint = ('A' * 40)
        }
    }
}
function Remove-AppxPackage {
    [CmdletBinding()]
    param([string]$Package)
    $script:removed++
    throw 'A conflicting registration was incorrectly removed.'
}
function New-FakePackage([string]$publisher,[string]$name,[string]$destination) {
    $manifest = Join-Path $source 'AppxManifest.xml'
    [IO.File]::WriteAllText($manifest,
        ('<Package><Identity Name="' + $name + '" Publisher="' +
          $publisher + '" Version="0.2.0.0" ProcessorArchitecture="x64"/></Package>'))
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
    [IO.Compression.ZipFile]::CreateFromDirectory($source,$destination)
}
function Expect-Blocked([scriptblock]$action,[string]$reason) {
    $blocked = $false
    try { & $action | Out-Null } catch { $blocked = $true }
    if (-not $blocked) { throw "Expected publisher transition to be blocked: $reason" }
}

try {
    $package = Join-Path $installDir 'DKEasyRenamer.Shell.msix'
    New-FakePackage 'CN=Future Public Signer' 'DKEasyRenamer.Shell' $package

    Write-Host 'PHASE 1: fresh registration and same-publisher updates are allowed'
    $script:fakeRegistered = @()
    & $guard -PackagePath $package | Out-Null
    $script:fakeRegistered = @([pscustomobject]@{
        Publisher = 'CN=Future Public Signer'
        PackageFullName = 'DKEasyRenamer.Shell_matching_fixture'
    })
    & $guard -PackagePath $package | Out-Null

    Write-Host 'PHASE 2: old development publisher cannot be silently replaced'
    $script:fakeRegistered = @([pscustomobject]@{
        Publisher = 'CN=DK Easy Renamer Development'
        PackageFullName = 'DKEasyRenamer.Shell_old_fixture'
    })
    Expect-Blocked { & $guard -PackagePath $package } 'mismatched registered publisher'

    Write-Host 'PHASE 3: preflight rejects mismatch before signature verification'
    $script:signatureCalls = 0
    Expect-Blocked { & $preflight -PackagePath $package } 'publisher mismatch during preflight'
    if ($script:signatureCalls -ne 0) {
        throw 'Preflight checked signature before blocking a publisher change.'
    }

    Write-Host 'PHASE 4: registration refuses mismatch before Remove-AppxPackage'
    foreach ($file in @('DK.EasyRenamer.App.exe','DK.EasyRenamer.Shell.dll','DK-Easy-Renamer.ico')) {
        [IO.File]::WriteAllText((Join-Path $installDir $file),'disposable fixture')
    }
    Copy-Item -LiteralPath $guard -Destination (Join-Path $installDir 'Test-ShellPublisherTransition.ps1')
    Expect-Blocked { & $register -InstallDir $installDir } 'destructive registration'
    if ($script:removed -ne 0) {
        throw 'Register-Shell called Remove-AppxPackage on a conflicting publisher.'
    }

    Write-Host 'PHASE 5: ambiguous or malformed package identities fail closed'
    $script:fakeRegistered = @(
        [pscustomobject]@{ Publisher = 'CN=Future Public Signer' },
        [pscustomobject]@{ Publisher = 'CN=Future Public Signer' }
    )
    Expect-Blocked { & $guard -PackagePath $package } 'multiple packages'
    $script:fakeRegistered = @()
    New-FakePackage 'CN=Future Public Signer' 'Some.Other.Package' $package
    Expect-Blocked { & $guard -PackagePath $package } 'wrong MSIX name'

    Write-Host 'PASS: matching identity accepted, mismatch blocked before registration changes.'
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
