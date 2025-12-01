[Setup]
; App information
AppName=Company360
AppVersion=1.0.12
AppPublisher=Company360
AppPublisherURL=
AppSupportURL=
AppUpdatesURL=
DefaultDirName={autopf}\Company360
DefaultGroupName=Company360
AllowNoIcons=yes
LicenseFile=
OutputDir=installer
OutputBaseFilename=company360-setup
SetupIconFile=..\assets\brand\c360-icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\company360.exe
VersionInfoVersion=1.0.12.13
VersionInfoCompany=Company360
VersionInfoDescription=Company360 - Comprehensive Business Management Application
VersionInfoCopyright=Copyright (C) 2024 Company360

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\company360.exe"; DestDir: "{app}"; Flags: ignoreversion

; Flutter runtime DLL
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; Plugin DLL files - CRITICAL: All required for app to run
Source: "build\windows\x64\runner\Release\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder - Contains app assets, fonts, and resources
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; IMPORTANT: Include ALL DLL files from Release folder (including any plugin DLLs)
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Company360"; Filename: "{app}\company360.exe"
Name: "{group}\{cm:UninstallProgram,Company360}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Company360"; Filename: "{app}\company360.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\Company360"; Filename: "{app}\company360.exe"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\company360.exe"; Description: "{cm:LaunchProgram,Company360}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Code]
// Custom code for version checking and installation
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
end;
