# CI only. Fake Get/Remove-AppxPackage responses and a disposable HKCU
# ownership record exercise the REAL Unregister-Shell.ps1 on a Windows runner.
# This script must never uninstall or register any real MSIX package.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'Owned-unregister smoke is restricted to disposable Windows CI runners.'
}

$key = 'HKCU:\Software\DKEasyRenamer'
if (Test-Path -LiteralPath $key) {
    throw 'A real Explorer owner record already exists on this runner. Refusing to run.'
}
$root = Join-Path $env:RUNNER_TEMP ('dk-owned-unregister-' + [guid]::NewGuid().ToString('N'))
$install = Join-Path $root 'installed app'
$exe = Join-Path $install 'DK.EasyRenamer.App.exe'
$msix = Join-Path $install 'DKEasyRenamer.Shell.msix'
$contents = Join-Path $root 'package'
$guard = Join-Path $PSScriptRoot '..\..\installer\windows\Test-ShellPublisherTransition.ps1'
$script = Join-Path $PSScriptRoot '..\..\installer\windows\Unregister-Shell.ps1'
New-Item -ItemType Directory -Path $install,$contents -Force | Out-Null
Copy-Item -LiteralPath $guard -Destination (Join-Path $install 'Test-ShellPublisherTransition.ps1')
[IO.File]::WriteAllText($exe,'harmless fixture')
Add-Type -AssemblyName System.IO.Compression

$global:DKUnregisterPackages = @()
$global:DKUnregisterRemoveCount = 0
$global:DKUnregisterRemoveFails = $false
$global:DKUnregisterLeavePackage = $false

function Get-AppxPackage {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -cne 'DKEasyRenamer.Shell') { throw 'Unexpected Appx query name.' }
    foreach ($pkg in $global:DKUnregisterPackages) { Write-Output $pkg }
}
function Remove-AppxPackage {
    [CmdletBinding()]
    param([string]$Package)
    if ($Package -ne 'DKEasyRenamer.Shell_fixture_owned') {
        throw 'Unexpected package removal target.'
    }
    $global:DKUnregisterRemoveCount++
    if ($global:DKUnregisterRemoveFails) { throw 'Simulated Remove-AppxPackage failure.' }
    if (-not $global:DKUnregisterLeavePackage) {
        $global:DKUnregisterPackages = @()
    }
}
function Set-FixtureManifest([string]$publisher) {
    $manifest = Join-Path $contents 'AppxManifest.xml'
    [IO.File]::WriteAllText($manifest,
        ('<Package><Identity Name="DKEasyRenamer.Shell" Publisher="' +
        $publisher + '" Version="0.1.2.0" ProcessorArchitecture="x64"/></Package>'))
    if (Test-Path -LiteralPath $msix) { Remove-Item -LiteralPath $msix -Force }
    [IO.Compression.ZipFile]::CreateFromDirectory($contents,$msix)
}
function Set-Owner([string]$path) {
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name ExecutablePath -Value $path
}
function Set-Package([string]$publisher) {
    $global:DKUnregisterPackages = @([pscustomobject]@{
        Publisher = $publisher
        PackageFullName = 'DKEasyRenamer.Shell_fixture_owned'
    })
}
function Reset-Fixture {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    $global:DKUnregisterPackages = @()
    $global:DKUnregisterRemoveCount = 0
    $global:DKUnregisterRemoveFails = $false
    $global:DKUnregisterLeavePackage = $false
}
function Assert-Blocked([string]$reason,[bool]$expectedRegistry) {
    $blocked = $false
    try { & $script -InstallDir $install | Out-Null }
    catch { $blocked = $true }
    if (-not $blocked) { throw "Unsafe unregister was accepted: $reason" }
    if ($global:DKUnregisterRemoveCount -ne 0) {
        throw "Unexpected package removal attempt: $reason"
    }
    if ((Test-Path -LiteralPath $key) -ne $expectedRegistry) {
        throw "Ownership registry was modified by a rejected unregister: $reason"
    }
}

try {
    Set-FixtureManifest 'CN=DK Easy Renamer Development'

    Write-Host 'PHASE 1: empty state -> harmless no-op'
    & $script -InstallDir $install | Out-Null
    if (Test-Path -LiteralPath $key -or $global:DKUnregisterRemoveCount -ne 0) {
        throw 'Empty-state unregister changed anything.'
    }

    Write-Host 'PHASE 2: package present but no owner -> fail closed'
    Set-Package 'CN=DK Easy Renamer Development'
    Assert-Blocked 'missing ownership record' $false

    Write-Host 'PHASE 3: foreign owner -> fail closed'
    Set-Owner (Join-Path $root 'elsewhere\DK.EasyRenamer.App.exe')
    Assert-Blocked 'foreign installation path' $true

    Write-Host 'PHASE 4: missing owner field -> fail closed'
    Reset-Fixture
    Set-Package 'CN=DK Easy Renamer Development'
    New-Item -Path $key -Force | Out-Null
    Assert-Blocked 'registry exists without ExecutablePath' $true

    Write-Host 'PHASE 5: matching folder, different publisher -> fail closed'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=Different Public Signing Publisher'
    Assert-Blocked 'cross-publisher registration' $true

    Write-Host 'PHASE 6: duplicate registrations -> fail closed'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=DK Easy Renamer Development'
    $global:DKUnregisterPackages += [pscustomobject]@{
        Publisher = 'CN=DK Easy Renamer Development'
        PackageFullName = 'DKEasyRenamer.Shell_duplicate_fixture'
    }
    Assert-Blocked 'multiple packages' $true

    Write-Host 'PHASE 7: missing package manifest -> fail closed'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=DK Easy Renamer Development'
    Remove-Item -LiteralPath $msix -Force
    Assert-Blocked 'missing MSIX' $true
    Set-FixtureManifest 'CN=DK Easy Renamer Development'

    Write-Host 'PHASE 8: removal failure keeps owner record'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=DK Easy Renamer Development'
    $global:DKUnregisterRemoveFails = $true
    $failed = $false
    try { & $script -InstallDir $install | Out-Null } catch { $failed = $true }
    if (-not $failed -or $global:DKUnregisterRemoveCount -ne 1 -or
        -not (Test-Path -LiteralPath $key)) {
        throw 'Failed removal destroyed the owner record or was ignored.'
    }

    Write-Host 'PHASE 9: incomplete removal keeps owner record'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=DK Easy Renamer Development'
    $global:DKUnregisterLeavePackage = $true
    $failed = $false
    try { & $script -InstallDir $install | Out-Null } catch { $failed = $true }
    if (-not $failed -or $global:DKUnregisterRemoveCount -ne 1 -or
        -not (Test-Path -LiteralPath $key)) {
        throw 'Unverified package removal lost owner record.'
    }

    Write-Host 'PHASE 10: verified matching owner + publisher unregisters once'
    Reset-Fixture
    Set-Owner $exe
    Set-Package 'CN=DK Easy Renamer Development'
    & $script -InstallDir $install | Out-Null
    if ($global:DKUnregisterRemoveCount -ne 1 -or
        (Test-Path -LiteralPath $key) -or $global:DKUnregisterPackages.Count -ne 0) {
        throw 'Owned package was not unregistered exactly once and cleaned.'
    }

    Write-Host 'PHASE 11: stale matching registry without package can be cleaned'
    Reset-Fixture
    Set-Owner $exe
    & $script -InstallDir $install | Out-Null
    if ((Test-Path -LiteralPath $key) -or $global:DKUnregisterRemoveCount -ne 0) {
        throw 'Stale owned record was not safely cleaned.'
    }

    Write-Host 'PASS: only owned, matching publisher can be removed; failures retain owner state.'
}
finally {
    if (Test-Path -LiteralPath $key) {
        Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name DKUnregisterPackages,DKUnregisterRemoveCount,DKUnregisterRemoveFails,DKUnregisterLeavePackage -Scope Global -ErrorAction SilentlyContinue
}
