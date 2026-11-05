# CI-only read-only readiness matrix. Fake MSIX ZIP packages and a temporary
# HKCU owner record are used. No Add-/Remove-AppxPackage invocation is allowed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'Migration readiness smoke is restricted to disposable Windows CI.'
}
$ownerKey = 'HKCU:\Software\DKEasyRenamer'
if (Test-Path -LiteralPath $ownerKey) {
    throw 'Real ownership key found on test runner. Refusing to overwrite it.'
}
Add-Type -AssemblyName System.IO.Compression
$root = Join-Path $env:RUNNER_TEMP ('dk-migration-readiness-' + [guid]::NewGuid().ToString('N'))
$install = Join-Path $root 'installed'
$archiveContents = Join-Path $root 'contents'
$oldMsix = Join-Path $install 'DKEasyRenamer.Shell.msix'
$nextMsix = Join-Path $root 'candidate.msix'
$exe = Join-Path $install 'DK.EasyRenamer.App.exe'
$check = Join-Path $PSScriptRoot '..\ux07\Get-ShellPublisherMigrationReadiness.ps1'
$global:DKMigrationTestRegistered = @()
$global:DKMigrationTestMutations = 0
New-Item -ItemType Directory -Path $install,$archiveContents -Force | Out-Null
[IO.File]::WriteAllText($exe,'temporary dummy EXE fixture')

function Get-AppxPackage {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -cne 'DKEasyRenamer.Shell') { throw 'Unexpected real Appx query.' }
    foreach ($package in $global:DKMigrationTestRegistered) { Write-Output $package }
}
function Add-AppxPackage {
    $global:DKMigrationTestMutations++
    throw 'Readiness report must never register an Appx package.'
}
function Remove-AppxPackage {
    $global:DKMigrationTestMutations++
    throw 'Readiness report must never remove an Appx package.'
}
function Set-Owner([string]$path) {
    New-Item -Path $ownerKey -Force | Out-Null
    Set-ItemProperty -Path $ownerKey -Name ExecutablePath -Value $path
}
function Set-Registered([string]$publisher) {
    $global:DKMigrationTestRegistered = @([pscustomobject]@{
        Publisher = $publisher
        PackageFullName = 'DKEasyRenamer.Shell_0.1.2.0_x64__fixture'
        PackageFamilyName = 'DKEasyRenamer.Shell_fixture'
        Version = '0.1.2.0'
    })
}
function New-TestMsix([string]$publisher,[string]$name,[string]$destination) {
    $manifest = Join-Path $archiveContents 'AppxManifest.xml'
    $body = '<Package><Identity Name="' + $name +
        '" Publisher="' + $publisher +
        '" Version="0.2.0.0" ProcessorArchitecture="x64"/></Package>'
    [IO.File]::WriteAllText($manifest,$body)
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Force
    }
    [IO.Compression.ZipFile]::CreateFromDirectory($archiveContents,$destination)
}
function Get-Report {
    $json = & $check -InstallDir $install -CandidatePackagePath $nextMsix
    if (-not $json) { throw 'Migration preflight did not produce JSON.' }
    $result = $json | ConvertFrom-Json
    if ($result.SchemaVersion -ne 1 -or $result.AutomaticMigrationAuthorized -ne $false) {
        throw 'Migration preflight unexpectedly authorized a destructive action.'
    }
    if ($global:DKMigrationTestMutations -ne 0) {
        throw 'Readiness report mutated an Appx registration.'
    }
    return $result
}
function Expect-Blocked([string]$reason) {
    $result = Get-Report
    if ($result.Decision -ne 'blocked' -or $reason -notin @($result.BlockReasons)) {
        throw "Expected blocked $reason; got $($result.Decision) / $($result.BlockReasons -join ',')"
    }
}

try {
    New-TestMsix 'CN=DK Easy Renamer Development' 'DKEasyRenamer.Shell' $oldMsix
    New-TestMsix 'CN=Future Approved Publisher' 'DKEasyRenamer.Shell' $nextMsix

    Write-Host 'PHASE 1: no registered shell identity => no migration needed'
    $result = Get-Report
    if ($result.Decision -ne 'no-shell-registration' -or
        $result.CandidateMsix.Publisher -ne 'CN=Future Approved Publisher' -or
        $result.CandidateSignatureStatus -eq 'Valid') {
        throw 'A fresh installation was incorrectly classified or unsigned bytes trusted.'
    }

    Write-Host 'PHASE 2: current owner + old publisher differs from candidate'
    Set-Owner $exe
    Set-Registered 'CN=DK Easy Renamer Development'
    $result = Get-Report
    if ($result.Decision -ne 'manual-publisher-migration-required' -or
        $result.ExistingPackage.Publisher -ne 'CN=DK Easy Renamer Development' -or
        $result.InstalledMsix.Sha256 -ne (Get-FileHash -LiteralPath $oldMsix -Algorithm SHA256).Hash -or
        @($result.RecoveryInputsStillRequired).Count -lt 4) {
        throw 'Missing essential recovery information or wrong migration classification.'
    }

    Write-Host 'PHASE 3: same publisher is not misclassified as a cross-family migration'
    New-TestMsix 'CN=DK Easy Renamer Development' 'DKEasyRenamer.Shell' $nextMsix
    $result = Get-Report
    if ($result.Decision -ne 'same-publisher') {
        throw "Same publisher was misclassified as $($result.Decision)"
    }
    New-TestMsix 'CN=Future Approved Publisher' 'DKEasyRenamer.Shell' $nextMsix

    Write-Host 'PHASE 4: another installation owns registry key'
    Set-Owner (Join-Path $root 'foreign\DK.EasyRenamer.App.exe')
    Expect-Blocked 'owner-record-not-owned-by-this-install'

    Write-Host 'PHASE 5: registered publisher disagrees with installed old MSIX'
    Set-Owner $exe
    Set-Registered 'CN=Wrong Publisher'
    Expect-Blocked 'registered-publisher-does-not-match-installed-msix'

    Write-Host 'PHASE 6: multiple current-user registrations are ambiguous'
    Set-Registered 'CN=DK Easy Renamer Development'
    $global:DKMigrationTestRegistered += [pscustomobject]@{
        Publisher = 'CN=DK Easy Renamer Development'
        PackageFullName = 'DKEasyRenamer.Shell_second'
        PackageFamilyName = 'DKEasyRenamer.Shell_second'
        Version = '0.1.2.0'
    }
    Expect-Blocked 'multiple-current-user-registrations'

    Write-Host 'PHASE 7: no owner record with a registered package is unsafe'
    Remove-Item -LiteralPath $ownerKey -Recurse -Force
    Set-Registered 'CN=DK Easy Renamer Development'
    Expect-Blocked 'registered-package-without-owner-record'

    Write-Host 'PHASE 8: old identity archive is missing'
    Set-Owner $exe
    Remove-Item -LiteralPath $oldMsix -Force
    Expect-Blocked 'registered-package-without-readable-installed-msix'
    New-TestMsix 'CN=DK Easy Renamer Development' 'DKEasyRenamer.Shell' $oldMsix

    Write-Host 'PHASE 9: missing installed app executable'
    Remove-Item -LiteralPath $exe -Force
    Expect-Blocked 'installed-executable-missing'
    [IO.File]::WriteAllText($exe,'temporary dummy EXE fixture')

    Write-Host 'PHASE 10: a foreign candidate package is refused before classification'
    New-TestMsix 'CN=Future Approved Publisher' 'Unrelated.App' $nextMsix
    $rejected = $false
    try { $null = Get-Report } catch { $rejected = $true }
    if (-not $rejected) { throw 'A foreign MSIX was accepted.' }

    if ($global:DKMigrationTestMutations -ne 0) {
        throw 'A readiness case invoked an Appx mutation command.'
    }
    Write-Host 'PASS: read-only migration classification, old identity checksum, ownership blockers and no Appx mutation.'
}
finally {
    if (Test-Path -LiteralPath $ownerKey) {
        Remove-Item -LiteralPath $ownerKey -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name DKMigrationTestRegistered,DKMigrationTestMutations -Scope Global -ErrorAction SilentlyContinue
}
