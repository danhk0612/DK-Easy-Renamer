# Disposable Windows CI only. Exercise production handoff with a temporary
# private test-CA-signed harmless console fixture, never a real app installer.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'Refusing to run outside ephemeral Windows CI.'
}

$id = [guid]::NewGuid().ToString('N')
$work = Join-Path $env:RUNNER_TEMP ('dk-ux07-' + $id)
$project = Join-Path $work 'probe'
$published = Join-Path $work 'bin'
$marker = Join-Path $work 'probe-args.txt'
$root = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Updates'
$helper = Join-Path $PSScriptRoot 'Invoke-VerifiedUpdate.ps1'
$fileName = 'DK-Easy-Renamer-0.2.0-x64-RELEASE.exe'
$rootCert = $null
$leaf = $null
$trusted = $false
$dirs = [System.Collections.Generic.List[string]]::new()
$oldMarker = $env:DK_UX07_CI_MARKER
$oldFail = $env:DK_UX07_CI_FAIL

function New-Stage([string]$source) {
    $dir = Join-Path $root ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dirs.Add($dir)
    $path = Join-Path $dir $fileName
    Copy-Item -LiteralPath $source -Destination $path
    return $path
}
function Invoke-Production([string]$path,[bool]$shell,[string]$digest) {
    $opts = @{
        InstallerPath = $path
        ExpectedSha256 = $digest
        ExpectedSignerSubject = $leaf.Subject
        ExpectedSignerThumbprint = $leaf.Thumbprint
    }
    if ($shell) { $opts.PreserveShellMenu = $true }
    & $helper @opts | Out-Null
}
function Assert-Args([string]$expected) {
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw 'No evidence of test fixture execution.'
    }
    $received = Get-Content -LiteralPath $marker -Raw
    if ($received -cne $expected) {
        throw "Expected installer arguments $expected but got $received"
    }
    Remove-Item -LiteralPath $marker -Force
}
New-Item -ItemType Directory -Path $work,$project,$published -Force | Out-Null
try {
    & dotnet new console -n HandoffProbe -f net10.0 --no-restore -o $project
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create disposable console fixture.' }
    @'
using System;
using System.IO;
internal static class Program {
    private static int Main(string[] options) {
        string marker = Environment.GetEnvironmentVariable("DK_UX07_CI_MARKER") ?? "";
        if (marker.Length == 0) return 99;
        File.WriteAllText(marker, string.Join("|", options));
        return Environment.GetEnvironmentVariable("DK_UX07_CI_FAIL") == "1" ? 17 : 0;
    }
}
'@ | Set-Content -LiteralPath (Join-Path $project 'Program.cs') -Encoding utf8
    & dotnet publish (Join-Path $project 'HandoffProbe.csproj') -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $published
    if ($LASTEXITCODE -ne 0) { throw 'Could not build harmless fixture.' }
    $probe = Join-Path $published 'HandoffProbe.exe'

    $rootCert = New-SelfSignedCertificate -Type Custom -Subject ('CN=DK-UX07-CI-Root-' + $id) -CertStoreLocation 'Cert:\CurrentUser\My' -KeyUsage CertSign,CRLSign -TextExtension @('2.5.29.19={critical}{text}ca=TRUE') -KeyExportPolicy NonExportable -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(1)
    $leaf = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=DK Easy Renamer CI Only Test Publisher' -Signer $rootCert -CertStoreLocation 'Cert:\CurrentUser\My' -KeyExportPolicy NonExportable -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(1)
    $certFile = Join-Path $work 'public-root.cer'
    Export-Certificate -Cert $rootCert -FilePath $certFile | Out-Null
    Import-Certificate -FilePath $certFile -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
    $trusted = $true
    $sdk = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10\bin'
    $signTool = Get-ChildItem -LiteralPath $sdk -Directory | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $signTool) { throw 'signtool.exe not found.' }
    & $signTool sign /fd SHA256 /sha1 $leaf.Thumbprint /s My $probe
    if ($LASTEXITCODE -ne 0) { throw 'Disposable test fixture signing failed.' }
    $sig = Get-AuthenticodeSignature -LiteralPath $probe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -ne $leaf.Thumbprint) {
        throw "Disposable test fixture Authenticode is not valid: $($sig.Status)"
    }

    $env:DK_UX07_CI_MARKER = $marker
    $env:DK_UX07_CI_FAIL = '0'

    Write-Host 'PHASE 1: app-only handoff succeeds and removes its own staging EXE/folder'
    $a = New-Stage $probe
    Invoke-Production $a $false (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash
    Assert-Args '/TASKS='
    if (Test-Path -LiteralPath (Split-Path -Parent $a)) { throw 'Successful app-only stage not cleaned.' }

    Write-Host 'PHASE 2: optional Explorer menu selection survives handoff'
    $b = New-Stage $probe
    Invoke-Production $b $true (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash
    Assert-Args '/TASKS=shellmenu'
    if (Test-Path -LiteralPath (Split-Path -Parent $b)) { throw 'Shell-enabled stage not cleaned.' }

    Write-Host 'PHASE 3: nonzero exit is rejected without deleting its stage'
    $c = New-Stage $probe
    $env:DK_UX07_CI_FAIL = '1'
    $failed = $false
    try { Invoke-Production $c $false (Get-FileHash -LiteralPath $c -Algorithm SHA256).Hash }
    catch { $failed = $true }
    if (-not $failed) { throw 'Nonzero exit was accepted.' }
    Assert-Args '/TASKS='
    if (-not (Test-Path -LiteralPath $c)) { throw 'Failure removed staged installer.' }
    $env:DK_UX07_CI_FAIL = '0'

    Write-Host 'PHASE 4: changed digest prevents any process launch'
    $d = New-Stage $probe
    $failed = $false
    try { Invoke-Production $d $false ('F' * 64) }
    catch { $failed = $true }
    if (-not $failed -or (Test-Path -LiteralPath $marker) -or -not (Test-Path -LiteralPath $d)) {
        throw 'Digest mismatch did not prevent launch or preserve stage.'
    }

    Write-Host 'PHASE 5: successful cleanup never deletes unrelated stage content'
    $e = New-Stage $probe
    $sentinel = Join-Path (Split-Path -Parent $e) 'USER-SENTINEL.txt'
    [IO.File]::WriteAllText($sentinel, 'keep')
    Invoke-Production $e $false (Get-FileHash -LiteralPath $e -Algorithm SHA256).Hash
    Assert-Args '/TASKS='
    if ((Test-Path -LiteralPath $e) -or -not (Test-Path -LiteralPath $sentinel) -or (Get-Content -LiteralPath $sentinel -Raw) -cne 'keep') {
        throw 'Cleanup touched unrelated content or failed to remove only installer.'
    }

    Write-Host 'PASS: temporary test-CA-signed fixture, success/failure exit, shell choice, digest and narrow cleanup.'
    Write-Host 'Test-only CA. This does not establish a publicly trusted release signer or actual Windows 11 GUI install.'
}
finally {
    $env:DK_UX07_CI_MARKER = $oldMarker
    $env:DK_UX07_CI_FAIL = $oldFail
    foreach ($dir in $dirs) {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if ($trusted -and $null -ne $rootCert) {
        Remove-Item -LiteralPath ('Cert:\CurrentUser\Root\' + $rootCert.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $leaf) { Remove-Item -LiteralPath ('Cert:\CurrentUser\My\' + $leaf.Thumbprint) -Force -ErrorAction SilentlyContinue }
    if ($null -ne $rootCert) { Remove-Item -LiteralPath ('Cert:\CurrentUser\My\' + $rootCert.Thumbprint) -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
