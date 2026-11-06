; DK Easy Renamer — unsigned, per-user Windows 11 classic Explorer installer.
; Deliberately includes NO MSIX, certificate, or modern context menu registration.
#ifndef PackageDir
  #error PackageDir must be supplied to ISCC
#endif
#ifndef ProductVersion
  #error ProductVersion must be supplied to ISCC
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
OutputBaseFilename=DK-Easy-Renamer-{#ProductVersion}-x64-RELEASE
SetupIconFile={#SourcePath}\..\..\assets\icons\DK-Easy-Renamer.ico
UninstallDisplayIcon={app}\DK.EasyRenamer.App.exe
LicenseFile={#SourcePath}\..\..\LICENSE
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Tasks]
Name: shellmenu; Description: "클래식 탐색기 우클릭 메뉴 등록 (Windows 11: 추가 옵션 표시)"; Flags: unchecked

[Files]
Source: "{#PackageDir}\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourcePath}\ClassicShell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\THIRD_PARTY_LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\DK Easy Renamer"; Filename: "{app}\DK.EasyRenamer.App.exe"; IconFilename: "{app}\DK-Easy-Renamer.ico"

[Code]
function GetPowerShellExecutable(): String;
begin
  Result := ExpandConstant('{pf}\PowerShell\7\pwsh.exe');
  if not FileExists(Result) then
    Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

function RunClassicShell(Mode: String): Boolean;
var
  ExitCode: Integer;
  Cmd: String;
begin
  Cmd := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{app}\ClassicShell.ps1') + '" -InstallDir "' +
    ExpandConstant('{app}') + '" -Mode ' + Mode;
  Result := Exec(GetPowerShellExecutable(),
    Cmd, ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if Result then Result := ExitCode = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if WizardIsTaskSelected('shellmenu') then
    begin
      if not RunClassicShell('Register') then
        RaiseException('Classic Explorer menu registration failed. Check %LOCALAPPDATA%\DK Easy Renamer\Logs\classic-shell.log.');
    end
    else if RegKeyExists(HKCU, 'Software\DKEasyRenamer') then
    begin
      if not RunClassicShell('Unregister') then
        RaiseException('Previous Explorer menu removal failed; please check the installed menu ownership.');
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if RegKeyExists(HKCU, 'Software\DKEasyRenamer') or
       RegKeyExists(HKCU, 'Software\Classes\*\shell\DKEasyRenamer') or
       RegKeyExists(HKCU, 'Software\Classes\Directory\shell\DKEasyRenamer') then
    begin
      if not RunClassicShell('Unregister') then
        RaiseException('Classic Explorer menu removal failed; uninstall stopped to avoid stale registration.');
    end;
  end;
end;
