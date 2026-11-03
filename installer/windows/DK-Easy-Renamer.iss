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

[Files]
Source: "{#PackageDir}\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageDir}\DKEasyRenamer.Shell.msix"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Register-Shell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\Unregister-Shell.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\THIRD_PARTY_LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\DK Easy Renamer"; Filename: "{app}\DK.EasyRenamer.App.exe"; IconFilename: "{app}\DK-Easy-Renamer.ico"

[Code]
#ifndef SignedBuild
function InitializeSetup(): Boolean;
begin
  MsgBox('This is an unsigned CI packaging candidate. It cannot register the Explorer extension. Obtain a trusted signed build for installation.', mbCriticalError, MB_OK);
  Result := False;
end;
#endif

function RunPowerShell(ScriptName: String): Boolean;
var
  ExitCode: Integer;
  Cmd: String;
begin
  Cmd := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{app}') + '\' + ScriptName + '" -InstallDir "' + ExpandConstant('{app}') + '"';
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    Cmd, ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if Result then
    Result := ExitCode = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not RunPowerShell('Register-Shell.ps1') then
      RaiseException('Explorer menu registration failed. The signed MSIX must be trusted by Windows. See the installation guide.');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if not RunPowerShell('Unregister-Shell.ps1') then
      RaiseException('Explorer menu removal failed; uninstall stopped to avoid orphan registrations.');
  end;
end;
