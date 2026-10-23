; Installationsprogramm für Jellyflex (Inno Setup 6).
; Bauen: tool\build_installer.ps1  (setzt AppVersion aus pubspec.yaml)
;
; - Installiert ohne Administratorrechte nach %LOCALAPPDATA%\Programs\Jellyflex
;   (auf Wunsch für alle Benutzer)
; - Startmenü-Eintrag mit fester App-Kennung (für die Sprungliste "Weiterschauen")
; - Beendet eine laufende Jellyflex-Instanz vor dem Aktualisieren
; - Deinstallation fragt, ob auch Einstellungen, Anmeldungen und der
;   Bild-Zwischenspeicher entfernt werden sollen; heruntergeladene Videos bleiben
; - Kein Internetzugriff, keine Zusatzsoftware

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Jellyflex"
#define AppExe "jellyflex.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Nie ändern – sonst entsteht eine zweite Installation neben der alten.
AppId={{6B1E3C2A-8D4F-4C7B-9A51-2F7E0D9C4B83}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\dist
OutputBaseFilename=Jellyflex-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern dynamic
; Läuft Jellyflex noch? (gleicher Name wie in windows/runner/main.cpp)
AppMutex=Jellyflex.SingleInstance
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"

[CustomMessages]
en.RemoveData=Also remove your Jellyflex settings, sign-ins and image cache from this computer?%n%nDownloaded videos in "Videos\Jellyflex" are kept.
de.RemoveData=Auch Einstellungen, Anmeldungen und den Bild-Zwischenspeicher von Jellyflex von diesem Computer entfernen?%n%nHeruntergeladene Videos unter "Videos\Jellyflex" bleiben erhalten.
fr.RemoveData=Supprimer aussi les réglages, connexions et le cache d'images de Jellyflex de cet ordinateur ?%n%nLes vidéos téléchargées dans « Vidéos\Jellyflex » sont conservées.
es.RemoveData=¿Quitar también los ajustes, inicios de sesión y la caché de imágenes de Jellyflex de este equipo?%n%nLos vídeos descargados en «Vídeos\Jellyflex» se conservan.
tr.RemoveData=Jellyflex ayarları, oturumlar ve görsel önbelleği de bu bilgisayardan kaldırılsın mı?%n%n"Videolar\Jellyflex" içindeki indirilen videolar korunur.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Jellyflex.App"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Jellyflex.App"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; Automatisches Update aus der App (still, mit /RELAUNCH): danach Jellyflex wieder starten.
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: ShouldRelaunch

[Code]
function ShouldRelaunch: Boolean;
begin
  Result := WizardSilent and (Pos('/RELAUNCH', Uppercase(GetCmdTail)) > 0);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  // Nur auf Nachfrage und nur die eigenen Ordner (nie die Videos).
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent then
    if MsgBox(CustomMessage('RemoveData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    begin
      DelTree(ExpandConstant('{userappdata}\Jellyflex'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\Jellyflex'), True, True, True);
    end;
end;
