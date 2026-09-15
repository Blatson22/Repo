@echo off
REM Lanzador del backend de inventario en segundo plano y silencioso.
REM Uso: inventario-servicio.bat   (desde la carpeta `backend`)

cd /d "%~dp0"

REM Si ya está escuchando en el puerto 8000, no lo relanzamos.
netstat -an | findstr ":8000 .*LISTEN" >nul 2>&1
if %errorlevel%==0 (
    echo [Inventario] El backend ya esta corriendo en el puerto 8000.
    exit /b 0
)

echo [Inventario] Arrancando backend en segundo plano...
start "" /min inventario-api.exe

exit /b 0