# Per-user Explorer shell registration with diagnostics outside the installation folder.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$logDirectory = Join-Path $env:LOCALAPPDATA 'DK Easy Renamer\Logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$log = Join-Path $logDirectory 'shell-registration.log'

function Write-Diagnostic([string]$message) {
    Add-Content -LiteralPath $log -Value ('[{0}] {1}' -f [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'), $message) -Encoding UTF8
}

try {
    $resolved = (Resolve-Path -LiteralPath $InstallDir).Path
    $packageFile = Join-Path $resolved 'DKEasyRenamer.Shell.msix'
    $appFile = Join-Path $resolved 'DK.EasyRenamer.App.exe'
    $comDll = Join-Path $resolved 'DK.EasyRenamer.Shell.dll'
    $iconFile = Join-Path $resolved 'DK-Easy-Renamer.ico'

    Write-Diagnostic "Registration started (install folder: $resolved)."
    foreach ($file in @($packageFile, $appFile, $comDll, $iconFile)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Required installation file is missing: $file"
        }
    }

    # Detect the common untrusted test certificate before removing a prior package.
    # Never install certificates or bypass signature verification automatically.
    $signature = Get-AuthenticodeSignature -LiteralPath $packageFile
    if ($null -ne $signature.SignerCertificate) {
        $cert = $signature.SignerCertificate
        Write-Diagnostic ("MSIX signer: {0}; thumbprint: {1}; signature status: {2}" -f $cert.Subject, $cert.Thumbprint, $signature.Status)
        $isSelfSigned = [string]::Equals($cert.Subject, $cert.Issuer, [StringComparison]::OrdinalIgnoreCase)
        if ($isSelfSigned) {
            $trusted = @(Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop |
                Where-Object Thumbprint -eq $cert.Thumbprint)
            if (-not $trusted) {
                throw "Test MSIX certificate is not trusted. Thumbprint: $($cert.Thumbprint). Verify the supplied .cer and explicitly trust it in the LocalMachine TrustedPeople store (administrator approval) before retrying."
            }
        }
    }
    else {
        Write-Diagnostic ("MSIX signer metadata unavailable from Get-AuthenticodeSignature (status: {0}); Appx will validate package." -f $signature.Status)
    }

    $existing = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
    foreach ($pkg in $existing) {
        Write-Diagnostic "Removing previous package: $($pkg.PackageFullName)"
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    }

    Write-Diagnostic 'Calling Add-AppxPackage with the signed installed MSIX and external app folder.'
    Add-AppxPackage -Path $packageFile -ExternalLocation $resolved -ErrorAction Stop
    $registered = @(Get-AppxPackage -Name 'DKEasyRenamer.Shell' -ErrorAction Stop)
    if ($registered.Count -ne 1) { throw 'Package registration could not be verified.' }

    $key = 'HKCU:\Software\DKEasyRenamer'
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name 'ExecutablePath' -Value $appFile
    Set-ItemProperty -Path $key -Name 'IconPath' -Value $iconFile
    Write-Diagnostic "Registration succeeded: $($registered[0].PackageFullName)"
    Write-Host "Registered per-user Explorer command: $($registered[0].PackageFullName)"
}
catch {
    $errorText = $_.ToString()
    try {
        Write-Diagnostic ("Registration FAILED: {0}" -f $errorText)
        Write-Diagnostic ("Exception HResult: 0x{0:X8}" -f ($_.Exception.HResult -band 4294967295))
        $events = @(Get-AppxLog -ErrorAction SilentlyContinue |
            Select-Object -Last 12 TimeCreated, Id, Message)
        if ($events.Count) {
            Write-Diagnostic ('Recent Appx deployment events:' + [Environment]::NewLine +
                ($events | Format-List | Out-String))
        }
    }
    catch {
        # Preserve the original deployment failure even if event-log access fails.
    }
    throw "Explorer menu registration failed: $errorText (diagnostics: $log)"
}
