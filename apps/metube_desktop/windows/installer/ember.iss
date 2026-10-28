; The MeTube Ember installer (Inno Setup 6.7).
;
; Built by tool\build-desktop.ps1, which passes the version and the folder
; of the release build:
;   ISCC.exe /DAppVersion=1.2.3 /DCrtDir=... ember.iss
;
; Installs for the current user only, with no administrator rights:
; %LOCALAPPDATA%\Programs\MeTube Ember. The app keeps its data elsewhere
; (%APPDATA%\MeTube Ember and %LOCALAPPDATA%\MeTube Ember), so an update
; never touches it and the uninstaller asks before removing it.

#ifndef AppVersion
  #error Pass the version: ISCC /DAppVersion=x.y.z ember.iss
#endif

; The values below are fixed for good at the first release: Windows knows
; the installed app by its AppId, and the app finds its Start menu shortcut
; and its data folders by its name (lib/identity.dart). A test holds them
; to the app. They are defines only so that a test build can install beside
; the real one without touching it (with NoRelaunch, so it never opens the
; app, which would use the real data).
#ifndef AppName
  #define AppName "MeTube Ember"
#endif
#ifndef AppIdGuid
  #define AppIdGuid "E116A4DE-C492-40C0-9094-8A734813AAFB"
#endif
#ifndef Scheme
  #define Scheme "metube"
#endif
#define AppExe "metube_desktop.exe"
; Created by the runner while the app is open (windows/runner/main.cpp).
#define RunningMutex "MeTubeEmber.Running"
#define Developer "sagheerys"
#define ProjectPage "https://sagheerys.github.io/metube-mobile/"

#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
; The Visual C++ runtime the app and its plugins link against, shipped
; beside the app so that a computer without it still starts the app: the
; x64 Microsoft.VC143.CRT folder of Visual Studio's redistributables. Not
; System32, which this 32-bit compiler sees as the 32-bit SysWOW64.
#ifndef CrtDir
  #error Pass the x64 runtime folder: ISCC /DCrtDir=...\x64\Microsoft.VC143.CRT
#endif

[Setup]
AppId={{{#AppIdGuid}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Developer}
AppPublisherURL={#ProjectPage}
AppSupportURL=https://github.com/sagheerys/metube-mobile/issues
AppUpdatesURL=https://github.com/sagheerys/metube-mobile/releases
AppCopyright=Copyright (C) 2026 {#Developer}
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} Setup
VersionInfoCompany={#Developer}
VersionInfoCopyright=Copyright (C) 2026 {#Developer}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
; Every install starts by asking for its language, with Windows' own
; already chosen, as most installers do; then a welcome page with the
; logo and who makes the app, and the terms and license to accept.
ShowLanguageDialog=yes
LanguageDetectionMethod=uilanguage
DisableWelcomePage=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
SetupIconFile=..\runner\resources\app_icon.ico
WizardStyle=modern dynamic
; Drawn by tool/make_icons.py --windows, one size per display scale.
WizardImageFile=wizard_large_*.bmp
WizardSmallImageFile=wizard_small_*.png
; An update closes the running app (it may be hidden in the tray, where it
; ignores a polite close) and opens it again from [Run].
CloseApplications=force
RestartApplications=no
Compression=lzma2/max
SolidCompression=yes
OutputDir=..\..\build\installer
OutputBaseFilename=MeTube-Ember-{#AppVersion}-windows-x64-setup

[Languages]
; The license pages are written by tool/make_installer_license.py: a
; preface in each language, then the GNU GPL v3 as it stands.
Name: "english"; MessagesFile: "compiler:Default.isl"; LicenseFile: "license_en.rtf"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"; LicenseFile: "license_ar.rtf"

[Messages]
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%n[name] is free, open-source software by {#Developer}, made to work with a MeTube server you run yourself.%n%nIt is recommended that you close all other applications before continuing.
; The pages on the way, in plainer Arabic than the stock translation.
arabic.SelectLanguageTitle=اختر لغة التثبيت
arabic.SelectLanguageLabel=اختر اللغة التي تريدها أثناء التثبيت.
arabic.ClickNext=انقر «التالي» للمتابعة، أو «إلغاء الأمر» للخروج من التثبيت.
arabic.WelcomeLabel1=مرحباً بك في تثبيت [name]
arabic.WelcomeLabel2=سيُثبَّت [name/ver] على هذا الكمبيوتر.%n%n[name] برنامج حرّ مفتوح المصدر من {#Developer}، يعمل مع سيرفر MeTube الذي تشغّله أنت.%n%nيُستحسن أن تغلق البرامج الأخرى قبل المتابعة.
arabic.WizardLicense=الشروط والرخصة
arabic.LicenseLabel=اقرأ المعلومات المهمة التالية قبل المتابعة.
arabic.LicenseLabel3=اقرأ الشروط والرخصة التالية، فلا بد من قبولها قبل متابعة التثبيت.
arabic.LicenseAccepted=&أوافق على الشروط والرخصة
arabic.LicenseNotAccepted=&لا أوافق
arabic.ReadyLabel1=كل شيء جاهز لتثبيت [name] على هذا الكمبيوتر.
arabic.ReadyLabel2a=انقر «تثبيت» للمتابعة، أو «السابق» لمراجعة اختياراتك أو تغييرها.
arabic.ReadyLabel2b=انقر «تثبيت» للمتابعة.
arabic.WizardInstalling=جارٍ التثبيت
arabic.InstallingLabel=انتظر قليلاً ريثما يُثبَّت [name] على هذا الكمبيوتر.
arabic.FinishedHeadingLabel=اكتمل تثبيت [name]
arabic.FinishedLabelNoIcons=ثُبِّت [name] على هذا الكمبيوتر.
arabic.FinishedLabel=ثُبِّت [name] على هذا الكمبيوتر، ويمكنك فتحه من اختصاراته.
arabic.ClickFinish=انقر «إنهاء» لإغلاق التثبيت.

[CustomMessages]
english.AboutLink=About the developer and the project: sagheerys.github.io/metube-mobile
arabic.AboutLink=عن المطوّر والمشروع: sagheerys.github.io/metube-mobile
english.AppRunning={#AppName} is still running. Close it, including from its icon by the clock, then click OK.
arabic.AppRunning=ما زال {#AppName} يعمل. أغلقه، ومن أيقونته بجانب الساعة أيضاً، ثم انقر «موافق».
english.DeleteData=Also delete the {#AppName} settings, tags, playlists and saved transcripts on this computer?%n%nYour downloaded files and everything on the server stay as they are.
arabic.DeleteData=هل تحذف أيضاً إعدادات {#AppName} ووسومك وقوائمك والنصوص المحفوظة على هذا الكمبيوتر؟%n%nتبقى ملفاتك المنزَّلة وكل ما على السيرفر كما هي.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; The previous version's assets, so none of them outlives the update.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#CrtDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; The name and the AppUserModelID are the ones the app gives itself, so
; Windows names it in notifications and the media flyout, and groups its
; taskbar button with this shortcut.
Name: "{userprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppName}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppName}"; Tasks: desktopicon

[Registry]
; metube://add?url=... links, as the MeTube browser extensions send them.
Root: HKCU; Subkey: "Software\Classes\{#Scheme}"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\{#Scheme}"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\{#Scheme}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"",0"
Root: HKCU; Subkey: "Software\Classes\{#Scheme}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
#ifndef NoRelaunch
; A silent run is an update the app started: open it again.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
#endif

[Code]
procedure AboutLinkClick(Sender: TObject);
var
  Code: Integer;
begin
  ShellExecAsOriginalUser('open', '{#ProjectPage}', '', '', SW_SHOWNORMAL, ewNoWait, Code);
end;

// Who makes the app, on the welcome page under its text: a link to the
// project page, where the developer, the source and the issues are.
procedure InitializeWizard();
var
  Link: TNewStaticText;
begin
  Link := TNewStaticText.Create(WizardForm);
  Link.Parent := WizardForm.WelcomePage;
  Link.Caption := CustomMessage('AboutLink');
  Link.Left := WizardForm.WelcomeLabel2.Left;
  Link.Top := WizardForm.WelcomeLabel2.Top + WizardForm.WelcomeLabel2.Height + ScaleY(16);
  Link.Font.Color := clHotLight;
  Link.Font.Style := [fsUnderline];
  Link.Cursor := crHand;
  Link.OnClick := @AboutLinkClick;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  while CheckForMutexes('{#RunningMutex}') do
  begin
    if UninstallSilent() or
      (MsgBox(CustomMessage('AppRunning'), mbError, MB_OKCANCEL) = IDCANCEL) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;
  // "Start with Windows" (launch_at_startup) would otherwise point at a
  // program that is gone.
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#AppName}');
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', '{#AppName}');
  // No is the default: a silent uninstall, or Enter, keeps the data.
  if not UninstallSilent() and
    (MsgBox(CustomMessage('DeleteData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
  begin
    DelTree(ExpandConstant('{userappdata}\{#AppName}'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\{#AppName}'), True, True, True);
  end;
end;
