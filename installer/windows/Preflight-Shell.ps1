# Runs before copying any application files. Does not change certificate stores.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackagePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$logDir = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Logs'
New-Item -Path $logDir -ItemType Directory -Force | Out-Null
$log = Join-Path $logDir 'shell-preflight.log'
try {
    $sign = Get-AuthenticodeSignature -LiteralPath $PackagePath -ErrorAction Stop
    if ($null -eq $sign.SignerCertificate) {
        throw "Signed MSIX certificate information cannot be read (status: $($sign.Status))."
    }
    $cert = $sign.SignerCertificate
    if ([string]::Equals($cert.Subject, $cert.Issuer,
        [StringComparison]::OrdinalIgnoreCase)) {
        # MSIX App Installer deployment requires the development signer
        # in LocalMachine TrustedPeople, not merely CurrentUser TrustedPeople.
        $trusted = @(Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop |
            Where-Object Thumbprint -eq $cert.Thumbprint)
        if ($trusted.Count -eq 0) {
            throw ("Self-signed MSIX certificate is not trusted in the LOCAL MACHINE TrustedPeople store. " +
                "Thumbprint: $($cert.Thumbprint). Compare the matching .cer from this build and " +
                "explicitly import it on a disposable Windows test device using an elevated PowerShell prompt.")
        }
    }
    elseif ($sign.Status -ne 'Valid') {
        throw "MSIX code-signing certificate is not valid (status: $($sign.Status))."
    }

    # After certificate validation but still BEFORE copying application files,
    # reject a different existing MSIX Publisher/package family.
    $publisherCheck = Join-Path $PSScriptRoot 'Test-ShellPublisherTransition.ps1'
    if (-not (Test-Path -LiteralPath $publisherCheck -PathType Leaf)) {
        throw 'Explorer publisher transition preflight is missing.'
    }
    & $publisherCheck -PackagePath $PackagePath | Out-Null

    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Preflight passed for signer $($cert.Subject) $($cert.Thumbprint)" |
        Add-Content -LiteralPath $log -Encoding UTF8
}
catch {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Preflight FAILED: $($_.ToString())" |
        Add-Content -LiteralPath $log -Encoding UTF8
    throw
}
