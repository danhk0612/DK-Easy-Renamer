# UX-07e: MSIX publisher migration — read-only readiness audit

This is preparation, **not migration**. The current development MSIX publisher is
CN=DK Easy Renamer Development. A different public publisher changes the MSIX
package family (Name + Publisher), so it cannot be treated as a normal update.

## Usage on Windows

Run the following from a checked-out source directory, or a trusted copy of
the standalone script, in the same Windows user account as the installation:

    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools\ux07\Get-ShellPublisherMigrationReadiness.ps1 -InstallDir "C:\Users\example\AppData\Local\Programs\DK Easy Renamer" -CandidatePackagePath "C:\temp\new-signed-shell.msix"

The script **only reads** the current user's Appx registration, HKCU owner path,
the currently installed MSIX archive, the candidate manifest/signature and file
hashes. It prints a JSON report to stdout. It does NOT write a report file,
copy/restore files, change certificates, install/uninstall a package, or launch
the installer. The JSON includes the local Windows installation path: do not
upload an unredacted real-user report to public logs or GitHub issues.

SchemaVersion is 1 and AutomaticMigrationAuthorized is always false, even
when the report says the current registration is consistent.

Decision values:

- no-shell-registration: the current Windows user has no Explorer identity
  registered; this is NOT permission to install.
- same-publisher: an owned registration matches the incoming MSIX Publisher;
  this is NOT a valid-signature/version/install authorization.
- manual-publisher-migration-required: an owned, consistent current identity
  has a different Publisher from the candidate. No automatic removal is offered.
- blocked: missing or contradictory ownership/registration/archive state.
  Consult BlockReasons and leave the existing installation untouched.

The report records the old registered PackageFullName, PackageFamilyName,
publisher, version; the old installed MSIX manifest and SHA-256 if readable;
candidate identity, SHA-256, signing status, subject/thumbprint; and required
recovery prerequisites. This is a snapshot of **metadata**, not binary/data
backup, and an unsigned mock candidate can still be classified for diagnostics
without ever being trusted.

## Prerequisites to implement and enable a future migration

1. Independently retain and verify the ORIGINAL signed old installer and MSIX,
   with checksums, correct publisher and approved rollback installation path.
   A checksum in a JSON readiness report is NOT an old installer backup.
2. Verify backup and restoration of DK Easy Renamer user settings, presets and
   other app-owned user data. Do not assume MSIX registration preserves these.
3. Approve a public code-signing provider and exact publisher/certificate
   subject and thumbprint. Validate EXE, installer, and MSIX publisher alignment.
4. Design a separate, explicit, user-approved migration with a rollback:
   verify old ownership; save state; remove only the verified old registration;
   register the verified new identity; check the Windows 11 first-level Explorer
   menu and user data; on failure, restore exactly the old identity and data.
   Reject ambiguous packages/owners instead of guessing.
5. Test both success and every meaningful rollback/failure path on a disposable
   actual Windows 11 machine, not just Windows Server CI.

Step 4 is NOT implemented in this PR. There is no option to run or enable it.
No public signing provider or Store distribution path is selected. No
certificate is imported, private key stored, Release/tag published or product
version changed.

## CI scope

tools/t04/Smoke-MigrationReadiness.ps1 uses fake ZIP/MSIX files, a test-only
HKCU ownership key and mocked Appx package enumeration on a disposable GitHub
Windows CI runner. It verifies fresh, same-publisher and changed-publisher
classification plus foreign owner, package mismatch, multiple registrations,
missing owner, missing old MSIX, missing app executable and foreign candidate
rejections. The mocks forbid invoking Add-AppxPackage and Remove-AppxPackage.
This is NOT a live Windows 11 publisher migration or rollback test.

Official Windows references:

- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/package-identity-overview
- https://learn.microsoft.com/en-us/powershell/module/appx/get-appxpackage?view=windowsserver2025-ps
