; Inno Setup script — Inventario (instalador unificado)
; Backend (inventario-api.exe) + App Flutter, servicio de Windows incluido.
;
; Ajusta las rutas SOURCE a tu máquina antes de compilar.

[Setup]
AppId={{B2A1C0DE-4F00-4A11-8E00-000000000001}
AppName=Inventario
AppVersion=1.0.0
AppPublisher=Su Empresa
DefaultDirName={autopf}\Inventario
DefaultGroupName=Inventario
UninstallDisplayIcon={app}\Inventario.exe
OutputDir=Output
OutputBaseFilename=Inventario-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin

[Files]
; Backend compilado (ajusta la ruta al .exe generado por PyInstaller)
Source: "..\Backend\dist\inventario-api.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
; App Flutter de escritorio: copia TODA la carpeta Release (exe + .dll + data/)
Source: "..\..\Proyecto_Flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
; Renombra el exe de la app fluter a Inventario.exe
Source: "..\..\Proyecto_Flutter\build\windows\x64\runner\Release\app2.exe"; DestDir: "{app}"; DestName: "Inventario.exe"; Flags: ignoreversion

[Icons]
Name: "{group}\Inventario"; Filename: "{app}\Inventario.exe"
Name: "{group}\Uninstall Inventario"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Inventario"; Filename: "{app}\Inventario.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; Flags: checked

[Run]
; Lanzador del backend en segundo plano (si no se usa el servicio)
Filename: "{app}\inventario-servicio.bat"; WorkingDir: "{app}\backend"; Flags: nowait

; Crear servicio de Windows que levanta el backend automática y silenciosamente
Filename: "sc"; Parameters: "create InventarioApi binPath=""\""{app}\backend\inventario-api.exe"\"""" start=automatic"; Flags: runhidden
Filename: "sc"; Parameters: "start InventarioApi"; Flags: runhidden

[UninstallRun]
Filename: "sc"; Parameters: "stop InventarioApi"; Flags: runhidden
Filename: "sc"; Parameters: "delete InventarioApi"; Flags: runhidden