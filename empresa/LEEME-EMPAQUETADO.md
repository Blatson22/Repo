# Empaquetado para distribución (Fase 4)

Guía paso a paso para entregar el sistema como un producto unificado en Windows.

## 1) Compilar el backend a ejecutable único

```bat
cd Backend
pip install pyinstaller
pyinstaller --onefile --name inventario-api main.py
```

Queda un único `Backend\dist\inventario-api.exe`.
Al ejecutarlo abre la API en `0.0.0.0:8000` y crea `inventario.db` a su lado.

> **Importante (PyInstaller `--onefile`):** el bootloader de un solo archivo
> aborta con *"Input redirection is not supported"* si se lanza desde una
> consola cuyo STDIN está redirigido (por ejemplo `cmd /c exe < algo`).
> En uso normal —doble clic, o arrancado como **Servicio de Windows**— arranca
> sin problema. Por eso el instalador usa el servicio en lugar de un lanzador.

## 2) Compilar el frontend

```bat
cd Proyecto_Flutter
flutter build windows
```

El binario queda en **`build\windows\x64\runner\Release\`**.
Ahí se genera `app2.exe` junto con `flutter_windows.dll` y la carpeta `data\`.
El instalador copia **toda esa carpeta** (ver `empresa\inventario.iss`).

> **Requisito en la máquina de destino:** las apps de escritorio de Flutter
> necesitan el *Microsoft Visual C++ Redistributable* (x64). Instálalo en la
> PC del cliente o añádelo al instalador (Inno Setup: sección `[Files]` con
> `vc_redist.x64.exe` y `[Run]` con `/install /quiet /norestart`).

## 3) Instalador unificado con Inno Setup

1. Instala [Inno Setup](https://jrsoftware.org/isdl.php).
2. Abre `inventario.iss` con Inno Setup y pulsa **Build → Compile**.
3. El instalador final se genera en `empresa\Output\`.

### Qué hace el instalador (`inventario.iss`)

- Instala `inventario-api.exe` y la app Flutter en `C:\Program Files\Inventario`.
- Tras instalar, crea el **servicio de Windows** `InventarioApi`
  (arranque automático y silencioso del backend).
- Deja accesos directos a la app en el escritorio y el menú Inicio.

## 4) Lanzar el backend en segundo plano (alternativa al servicio)

Si prefieres no usar un servicio, el lanzador `inventario-servicio.bat`
arranca el backend en silencio (ventana minimizada) y al cerrar la app lo
detiene. Existe el acceso directo "Inventario (Iniciar backend)".

## Notas

- Cambia en `config.dart` la URL base antes de compilar según el despliegue
  (LAN por IP, LAN por `.local` o túnel HTTPS remoto).
- El puerto predeterminado es el 8000. Si usas otro, ajusta también las
  reglas de firewall y la URL de Flutter.