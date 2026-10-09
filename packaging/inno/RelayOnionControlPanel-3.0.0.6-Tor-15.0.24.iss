#define MyAppName "Relay Onion Control Panel"
#define MyAppVersion "3.0.0.6"
#define MyTorVersion "15.0.24"
#define MyAppPublisher "Mohammad Mahdi Khosravi"
#define MyAppExeName "TorControlPanel.exe"
#define ReleaseRoot AddBackslash(SourcePath) + "..\\..\\release"
#define SourceDir AddBackslash(ReleaseRoot) + "RelayOnionControlPanel-3.0.0.6-TorExpertBundle-15.0.24-windows-x64"
#define InstallerOutputDir AddBackslash(ReleaseRoot) + "installer\\output"

[Setup]
AppId={{7C9D6E1A-DFC1-4BA5-9B4D-8A7A81A81265}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion} + Tor Expert Bundle {#MyTorVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Relay Onion Control Panel
DefaultGroupName=Relay Onion Control Panel
DisableProgramGroupPage=yes
OutputDir={#InstallerOutputDir}
OutputBaseFilename=RelayOnionControlPanel-3.0.0.6-TorExpertBundle-15.0.24-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile={#SourceDir}\TorControlPanel_Icon.ico
UninstallDisplayIcon={app}\TorControlPanel.exe
VersionInfoVersion=3.0.0.6
VersionInfoCompany=Mohammad Mahdi Khosravi
VersionInfoDescription=Relay Onion Control Panel installer
VersionInfoProductName=Relay Onion Control Panel
VersionInfoProductVersion=3.0.0.6
CloseApplications=yes
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\TorControlPanel.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\TorControlPanel_Icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Changelog.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Defaults.ini"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Translations.ini"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\resources\locales\*.ini"; DestDir: "{app}\resources\locales"; Flags: ignoreversion
Source: "{#SourceDir}\MANIFEST.sha256"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Tor\*"; DestDir: "{app}\Tor"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\Data\geoip"; DestDir: "{app}\Data"; Flags: ignoreversion
Source: "{#SourceDir}\Data\geoip6"; DestDir: "{app}\Data"; Flags: ignoreversion
Source: "{#SourceDir}\Data\torrc-defaults"; DestDir: "{app}\Data"; Flags: ignoreversion
Source: "{#SourceDir}\Data\User.template\*"; DestDir: "{app}\Data\User"; Flags: ignoreversion onlyifdoesntexist
Source: "{#SourceDir}\Skins\*"; DestDir: "{app}\Skins"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#SourceDir}\Licenses\*"; DestDir: "{app}\Licenses"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#SourceDir}\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\install\*"; DestDir: "{app}\install"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\optional\*"; DestDir: "{app}\optional"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Relay Onion Control Panel"; Filename: "{app}\TorControlPanel.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall Relay Onion Control Panel"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Relay Onion Control Panel"; Filename: "{app}\TorControlPanel.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\TorControlPanel.exe"; Description: "Launch Relay Onion Control Panel"; Flags: nowait postinstall skipifsilent

[InstallDelete]
Type: files; Name: "{app}\Tor\pluggable_transports\snowflake-client.exe"
Type: files; Name: "{app}\Tor\pluggable_transports\webtunnel-client.exe"

[UninstallDelete]
Type: files; Name: "{app}\Data\User\lock*"
Type: files; Name: "{app}\Data\User\*.tmp"

