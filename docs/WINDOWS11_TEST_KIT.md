# DK Easy Renamer — Windows 11 test kit (not a public Release)

This document is the entry point for testing a Git checkout on an isolated Windows 11 x64 PC or VM. Test installers are GitHub Actions artifacts, not GitHub Releases. **No public signing identity or Windows 11 final approval is claimed.**

## Choose a test path

| Path | Prerequisites | Covers | Does not cover |
|---|---|---|---|
| A — source launch | Git, .NET 10 SDK | WPF GUI, temporary-file previews, Apply/Undo | Installed Explorer context menu |
| B — APP-ONLY installer (recommended first) | Git, GitHub CLI, Windows 11 VM | Installed GUI, Apply/Undo, uninstall | Explorer context menu, signed MSIX |
| C — Explorer installer | Path B plus explicit trust of the matching public test certificate | Installed GUI, MSIX and Explorer context menu | Public signing, end-user distribution |

**Use only generated TEMP/DK-EasyRenamer-T04-* files.** Avoid real documents, network shares and production PCs. Take a VM snapshot before installing a signed package, especially if a prior development version is present. Windows may warn about an unsigned APP-ONLY test installer; do not disable system security protections to bypass a warning.

## 1. Get the source with Git

In ordinary Windows PowerShell, first install Git. For the installer paths, install [GitHub CLI](https://cli.github.com/) and sign in with the command shown below.

First checkout:

    git clone https://github.com/danhk0612/DK-Easy-Renamer.git
    cd DK-Easy-Renamer
    gh auth login

Existing checkout:

    git checkout main
    git pull --ff-only

The download script refuses non-main checkouts, locally modified tracked files, failed CI runs and artifacts built from a different Git commit.

## 2A. Test directly from source (no installer or certificate)

Requires the .NET 10 SDK. From the repository root:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t03\Generate-Icon.ps1
    dotnet restore .\DK-Easy-Renamer.sln
    dotnet build .\DK-Easy-Renamer.sln -c Release --no-restore
    dotnet test .\DK-Easy-Renamer.sln -c Release --no-build
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\New-TestFixtures.ps1
    dotnet run --project .\src\DK.EasyRenamer.App\DK.EasyRenamer.App.csproj -c Release --no-build

Open the printed fixture directory and drag generated files into the application. **Source launch does not install the modern Explorer menu.**

## 2B. Download and test an APP-ONLY installer

Requires authenticated GitHub CLI but **does not require Visual Studio or a .NET SDK**.

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Get-Windows11TestBuild.ps1 -Mode AppOnly

The run discovery queries GitHub Actions by the exact Git SHA and uses only completed/successful main runs. It is regression-tested under Windows PowerShell 5.1. If GitHub's run-listing API is temporarily unavailable, inspect the successful build under [Actions](https://github.com/danhk0612/DK-Easy-Renamer/actions/workflows/ci.yml) and pass its numeric ID explicitly using `-RunId <id>`; the script still rejects an ID from the wrong commit or workflow.

The script finds successful main CI for the exact local Git SHA, downloads the artifact named **t05-UNSIGNED-APP-ONLY-TEST-ONLY**, verifies the EXE SHA-256 against its checksum file and prints the installer path. Nothing is executed or installed automatically. The bundle is under **artifacts/windows11-test/RUN_ID/AppOnly** (ignored by Git).

Review the printed EXE and launch it **manually inside the VM**. APP-ONLY intentionally omits Explorer registration. Uninstall from Windows Settings > Installed apps after testing.

## 2C. Download and test signed Explorer integration

Inside the isolated test VM, after removing any incompatible existing test version:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Get-Windows11TestBuild.ps1 -Mode Explorer

This downloads **t05-DEV-SIGNED-TEST-ONLY-MANUAL-TRUST** into **artifacts/windows11-test/RUN_ID/Explorer**, verifies the setup and MSIX SHA-256, Authenticode signers and matching **public** development certificate. The private signing key is never downloaded. The script does not trust or install anything.

If you approve the exact downloaded signer, inspect the public certificate/thumbprint printed by the script. In a separately opened **elevated PowerShell on the disposable VM only**, import the exact matching public CER (replace the placeholder with the actual printed path):

    Import-Certificate -FilePath '<exact bundle path>\installer\DKEasyRenamer-TEST-ONLY.cer' -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'

Do not import unrelated certificates. An ordinary CI run uses a **new short-lived certificate each time**, so a prior test certificate will not cover a newly generated signed build. This self-signed certificate is not for public distribution.

Launch the verified signed-probe EXE manually. After installation, run the read-only registration check:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Check-InstalledShell.ps1

Restart Explorer or sign out/in as needed to confirm the actual **Windows 11 first-level file/folder context menu**. Static registration checks cannot prove real menu invocation.

When finished, uninstall using Windows Settings > Installed apps, then check:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\Check-RemovedShell.ps1

If you trusted an ephemeral certificate, remove **only that exact thumbprint** from the test VM's LocalMachine TrustedPeople certificate store after checking no other installation needs it. Never remove unrelated certificates.

## 3. Interactive test checklist

Generate an independent disposable fixture directory for each test session:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\t04\New-TestFixtures.ps1

- [ ] GUI opens with readable title, correct icon and controls in both themes
- [ ] Add files, Korean/Japanese filenames and folders; the same folder with and without a trailing separator is one row
- [ ] Natural sort yields file1, file2, file10; manual ordering stays stable
- [ ] Sequence start/step/width and excluded rows produce expected previews; extensions remain unchanged by default
- [ ] Invalid and duplicate targets block Apply without modifying original test files
- [ ] Apply presents an explicit Yes/No confirmation; approving renames a fixture without altering contents
- [ ] Undo restores original name and content; an occupied original path blocks unsafe rollback
- [ ] Signed Explorer mode only: one **DK Easy Renamer** flyout is visible in the first-level context menu for files/folders; expanding it shows **일반 이름 변경...**, **빠른 순번 변경...**, **빠른 찾기·바꾸기...**
- [ ] Each of those three menu actions opens the existing app with exactly the selected file/folder paths, with quick rules preselected and **without automatic rename**
- [ ] Signed install and uninstall preserve fixture data and correctly remove shell registration; an upgrade remains a separate test

Record PASS / FAIL / BLOCKED, Windows 11 build, Git SHA, CI run ID, installer SHA-256 and errors/screenshots. See [T04 acceptance](T04_ACCEPTANCE.md) and [issue #7](https://github.com/danhk0612/DK-Easy-Renamer/issues/7) for more detailed cases.

## 4. Rebuild test artifacts / reuse the signing identity

Test artifacts are retained for **14 days**, not indefinitely. The download script rejects expired, failed or mismatched artifacts. If the successful main build for the checked-out SHA has expired, manually run the existing CI and retry the download:

    gh workflow run ci.yml --ref main -f stable_dev_signing=false -R danhk0612/DK-Easy-Renamer

For repeated Explorer tests with one trusted development certificate, see the existing [stable signing instructions](INSTALLER.md#stable-development-signing-for-repeatable-t04-installers-preferred). This requires a private PFX **outside Git**, a protected GitHub dev-signing environment, owner approval and a manual stable_dev_signing=true workflow run. Its artifact is named **t05-STABLE-DEV-SIGNED-TEST-ONLY**. Never put the PFX/password in Git or issues. The test download helper uses ordinary main CI artifacts, not the protected secrets.

**Publication boundary:** No public Release/tag, automatic certificate trust, or production in-app update is authorized by these artifacts. Windows 11 interactive acceptance and a publicly trusted publisher identity remain independent gates.
