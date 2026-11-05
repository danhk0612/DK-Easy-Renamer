; DK Easy Renamer — Windows 11 x64 per-user installer, Inno Setup 6.x.
; CI can compile an UNSIGNED candidate, which is deliberately not installable.
#ifndef PackageDir
  #error PackageDir must be supplied to ISCC
#endif
#ifndef ProductVersion
  #error ProductVersion must be supplied to ISCC
#endif
#ifndef BuildFlavor
  #error BuildFlavor must be supplied to ISCC
#endif
#define AppGuid "{{6ED457F1-25EF-4B35-B696-6F6064F7E6AB}"

[Setup]
AppId={#AppGuid}
AppName=DK Easy Renamer
AppVersion={#ProductVersion}
AppVerName=DK Easy Renamer {#ProductVersion}
AppPublisher=danhk0612
AppPublisherURL=https://github.com/danhk0612/DK-Easy-Renamer
AppSupportURL=https://github.com/danhk0612/DK-Easy-Renamer/issues
DefaultDirName={localappdata}\Programs\DK Easy Renamer
DefaultGroupName=DK Easy Renamer
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.22000
UsePreviousAppDir=yes
OutputDir={#PackageDir}\installer
OutputBaseFilename=DK-Easy-Renamer-{#ProductVersion}-x64-{#BuildFlavor}
SetupIconFile={#SourcePath}\..\..\assets\icons\DK-Easy-Renamer.ico
UninstallDisplayIcon={app}\DK.EasyRenamer.App.exe
#ifdef SignedBuild
SignTool=dkrenamersign
SignedUninstaller=yes
#endif
LicenseFile={#SourcePath}\..\..\LICENSE
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Tasks]
Name: shellmenu; Description: "Windows 11 탐색기 우클릭 메뉴 등록"; Flags: unchecked

[Files]
;; The certificate is checked only for the optional modern context menu.
;; An untrusted package must not block the standalone application installer.
Source: "{#SourcePath}\Preflight-Shell.ps1"; Flags: dontcopy noencryption
Source: "{#SourcePath}\Test-ShellPublisherTransition.ps1"; Flags: dontcopy noencryption
Source: "{#PackageDir}\DKEasyRenamer.Shell.msix"; Flags: dontcopy noencryption
Source: "{#PackageDir}\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageDir}\DKEasyRenamer.Shell.msix"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Preflight-Shell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Test-ShellPublisherTransition.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Query-ShellState.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Register-Shell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Unregister-Shell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\THIRD_PARTY_LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\DK Easy Renamer"; Filename: "{app}\DK.EasyRenamer.App.exe"; IconFilename: "{app}\DK-Easy-Renamer.ico"

[Code]
function GetPowerShellExecutable(): String;
begin
  // Prefer PowerShell 7 when already installed, but do not make it a dependency.
  // Some Windows Server builds ship a broken 32-bit Windows PowerShell security module.
  Result := ExpandConstant('{pf}\PowerShell\7\pwsh.exe');
  if not FileExists(Result) then
    Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

#ifndef SignedBuild
  #ifndef AppOnlyBuild
function InitializeSetup(): Boolean;
begin
  MsgBox('This is an unsigned CI packaging candidate. It cannot register the Explorer extension. Obtain a trusted signed build for installation.', mbCriticalError, MB_OK);
  Result := False;
end;
  #endif
#endif


#ifdef SignedBuild
var
  ShellTrustChecked: Boolean;
  ShellTrustAvailable: Boolean;

function CheckShellCertificate(): Boolean;
var
  Cmd: String;
  ExitCode: Integer;
begin
  ExtractTemporaryFile('Preflight-Shell.ps1');
  ExtractTemporaryFile('Test-ShellPublisherTransition.ps1');
  ExtractTemporaryFile('DKEasyRenamer.Shell.msix');
  Cmd := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{tmp}\Preflight-Shell.ps1') + '" -PackagePath "' +
    ExpandConstant('{tmp}\DKEasyRenamer.Shell.msix') + '"';
  Result := Exec(GetPowerShellExecutable(),
    Cmd, ExpandConstant('{tmp}'), SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if Result then Result := ExitCode = 0;
end;

function IsShellTrusted(): Boolean;
begin
  if not ShellTrustChecked then
  begin
    ShellTrustChecked := True;
    ShellTrustAvailable := CheckShellCertificate();
  end;
  Result := ShellTrustAvailable;
end;

procedure CurPageChanged(CurPageID: Integer);
var
  Index: Integer;
begin
  if CurPageID = wpSelectTasks then
  begin
    Index := WizardForm.TasksList.Items.IndexOf('Windows 11 탐색기 우클릭 메뉴 등록');
    if Index >= 0 then
    begin
      WizardForm.TasksList.ItemEnabled[Index] := IsShellTrusted();
      if not ShellTrustAvailable then
        WizardForm.TasksList.Checked[Index] := False;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  // Silent /TASKS=shellmenu must not bypass certificate validation.
  if WizardIsTaskSelected('shellmenu') and not CheckShellCertificate() then
    Result := 'Explorer menu certificate is not trusted. Uncheck the optional ' +
      'context menu task to install the base app without shell integration.';
end;
#endif

#ifndef SignedBuild
procedure CurPageChanged(CurPageID: Integer);
var
  Index: Integer;
begin
  if CurPageID = wpSelectTasks then
  begin
    Index := WizardForm.TasksList.Items.IndexOf('Windows 11 탐색기 우클릭 메뉴 등록');
    if Index >= 0 then
    begin
      WizardForm.TasksList.Checked[Index] := False;
      WizardForm.TasksList.ItemEnabled[Index] := False;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardIsTaskSelected('shellmenu') then
    Result := 'An unsigned application-only build cannot register the Windows 11 Explorer menu.';
end;
#endif

function RunPowerShell(ScriptName: String): Boolean;
var
  ExitCode: Integer;
  Cmd: String;
begin
  Cmd := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{app}') + '\' + ScriptName + '" -InstallDir "' + ExpandConstant('{app}') + '"';
  Result := Exec(GetPowerShellExecutable(),
    Cmd, ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if Result then
    Result := ExitCode = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    #ifdef SignedBuild
    if WizardIsTaskSelected('shellmenu') then
    begin
      if not RunPowerShell('Register-Shell.ps1') then
        RaiseException('Explorer menu registration failed. Check %LOCALAPPDATA%\DK Easy Renamer\Logs\shell-registration.log for the exact Windows Appx error code.');
    end
    else
    #endif
    begin
      // On a fresh app-only install there is nothing to remove. Avoid invoking
      // package deployment PowerShell when no registration belongs to this user.
      if RegKeyExists(HKCU, 'Software\DKEasyRenamer') then
      begin
        if not RunPowerShell('Unregister-Shell.ps1') then
          RaiseException('Explorer menu removal failed. The application files remain installed.');
      end;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if RegKeyExists(HKCU, 'Software\DKEasyRenamer') then
    begin
      if not RunPowerShell('Unregister-Shell.ps1') then
        RaiseException('Explorer menu removal failed; uninstall stopped to avoid orphan registrations.');
    end;
  end;
end;
