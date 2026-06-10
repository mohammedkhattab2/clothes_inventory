; DeltaErp.iss — Inno Setup installer for Flutter Windows Release
; Compile on YOUR machine after: flutter build windows --release
; The client only runs the generated Setup.exe — no Release folder required on their PC.

#define MyAppName      "Delta ERP"
#define MyAppPublisher "Delta"
#define MyAppVersion   "1.0.0"
#define MyAppExeName   "DeltaErp.exe"

; Paths relative to this script (installer\DeltaErp.iss)
#define MyAppRoot      AddBackslash(SourcePath) + ".."
#define ReleaseDir     AddBackslash(MyAppRoot) + "build\windows\x64\runner\Release"
#define ReleaseExe     ReleaseDir + "\" + MyAppExeName
#define ReleaseAppSo   ReleaseDir + "\data\app.so"
#define OcrTesseract   ReleaseDir + "\ocr\tesseract.exe"
#define InstallerAssets AddBackslash(SourcePath) + "assets"
#define OutputFolder   AddBackslash(SourcePath) + "output"

; --- Compile-time checks (run only when YOU build the installer) ---
#ifexist ReleaseExe
#else
  #error "Release build not found. Run first:" + #13#10 + "  flutter build windows --release" + #13#10 + #13#10 + "Expected:" + #13#10 + "  " + ReleaseExe
#endif

#ifexist ReleaseAppSo
#else
  #error "Flutter Release data missing (app.so). Rebuild with:" + #13#10 + "  flutter build windows --release" + #13#10 + #13#10 + "Expected:" + #13#10 + "  " + ReleaseAppSo
#endif

#ifexist AddBackslash(InstallerAssets) + "vc_redist.x64.exe"
#else
  #error "Microsoft VC++ redist missing. Download vc_redist.x64.exe and place it in:" + #13#10 + "  installer\assets\vc_redist.x64.exe" + #13#10 + #13#10 + "https://aka.ms/vs/17/release/vc_redist.x64.exe"
#endif

#ifexist OcrTesseract
#else
  #warning "OCR bundle missing in Release (ocr\tesseract.exe). Build will continue, but OCR may not work for customers until you rebuild with the ocr/ folder in the project root."
#endif

#ifexist AddBackslash(MyAppRoot) + "windows\runner\resources\app_icon.ico"
  #define SetupIcon AddBackslash(MyAppRoot) + "windows\runner\resources\app_icon.ico"
  #define HasSetupIcon
#else
  #ifexist AddBackslash(InstallerAssets) + "favicon.ico"
    #define SetupIcon AddBackslash(InstallerAssets) + "favicon.ico"
    #define HasSetupIcon
  #endif
#endif

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}}

AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

OutputBaseFilename=DeltaERP_Setup_{#MyAppVersion}
OutputDir={#OutputFolder}

#if HasSetupIcon
SetupIconFile={#SetupIcon}
#endif

VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName}
VersionInfoProductName={#MyAppName}

Compression=lzma2/ultra64
SolidCompression=yes

WizardStyle=modern

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

MinVersion=10.0

DisableProgramGroupPage=no
DisableDirPage=no

UsePreviousAppDir=yes
UsePreviousGroup=yes

CloseApplications=yes
CloseApplicationsFilter=*.exe
RestartApplications=no

AppMutex=DeltaErpMutex

; SignTool=signtool sign /f "your.pfx" /p password /t http://timestamp.digicert.com /fd sha256 $f

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Entire Flutter Release output (exe, data, dlls, ocr/, etc.)
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; VC++ runtime — extracted to {tmp} during install, not shipped inside {app}
Source: "{#InstallerAssets}\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; \
  Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Microsoft Visual C++ Runtime..."; \
  Flags: waituntilterminated; \
  Check: NeedsVCRedistInstall

Filename: "{app}\{#MyAppExeName}"; \
  WorkingDir: "{app}"; \
  Description: "{cm:LaunchProgram,{#MyAppName}}"; \
  Flags: nowait postinstall skipifsilent unchecked

[Code]
function NeedsVCRedistInstall: Boolean;
var
  Version: String;
begin
  Result := True;

  if RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version',
    Version) then
  begin
    Result := False;
    Exit;
  end;

  if RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version',
    Version) then
  begin
    Result := False;
  end;
end;
