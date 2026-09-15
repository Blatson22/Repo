# Inventario — Sistema Cliente-Servidor (Backend + Flutter)

Aplicación de inventario compuesta por:

| Componente   | Tecnología                     | Carpeta                          |
|--------------|--------------------------------|----------------------------------|
| Backend      | Python · FastAPI · SQLite      | `Backend/`                       |
| Frontend     | Flutter (app de escritorio/web)| `Proyecto_Flutter/`              |

El backend expone una API REST y guarda los datos en `inventario.db` (SQLite).
El frontend la consume y permite hacer el CRUD de productos.

---

## 1. Puesta en marcha rápida (desarrollo en esta PC)

### Backend

```bash
cd Backend
pip install -r requirements.txt
python main.py
```

El servidor queda escuchando en **0.0.0.0:8000** (visible para toda la red local).
Documentación interactiva en <http://127.0.0.1:8000/docs>.

### Frontend

```bash
cd Proyecto_Flutter
flutter pub get
flutter run          # escritorio / emulador
flutter build web    # o compilar para otra plataforma
```

> Para cambiar a qué API apunta la app, edita **una sola variable**:
> `Proyecto_Flutter/lib/config.dart` → `const String apiBaseUrl = 'http://...'`.

---

## 2. Fase 2 — Despliegue en la PC de gama baja (red local / LAN)

Objetivo: validar la arquitectura cliente-servidor real **sin depender de la nube**.

### Paso A: Traslado del backend

1. Copia la carpeta `Backend/` a la PC de gama baja (pendrive o red).
2. Instala Python 3.12 en esa PC (<https://python.org>) marcando
   *"Add Python to PATH"*.
3. Abre una terminal en la carpeta `Backend` y ejecuta:

   ```bash
   pip install -r requirements.txt
   python main.py
   ```

   No cierres la terminal mientras quieras que el servidor esté activo.

### Paso B: Obtener la IP privada y abrir el firewall

1. En la PC de gama baja abre otra terminal y ejecuta:

   - **Windows:** `ipconfig`  → anota la IP de tu adaptador activo (ej. `192.168.1.15`)
   - **Linux:** `ip a`  → lo mismo (ej. `192.168.1.15`)

2. Firewall: cuando el sistema lo pregunte tras lanzar `python main.py`,
   pulsa **Permitir acceso** para el puerto **8000**.
   Si no aparece el aviso, añádelo manualmente:

   ```bash
   netsh advfirewall firewall add rule name="Inventario API 8000" dir=in action=allow protocol=tcp localport=8000
   ```

### Paso C: Vincular Flutter a esa IP

En la PC principal / teléfono de pruebas:

1. Abre `Proyecto_Flutter/lib/config.dart`.
2. Cambia la dirección base:

   ```dart
   const String apiBaseUrl = 'http://192.168.1.15:8000';  // IP real de la PC gama baja
   ```

3. Recompila/relanza la app.
4. Prueba **crear, consultar y editar** productos: verás la sincronización
   inmediata de la base de datos alojada en la PC vieja.

> Emulador Android: usa `http://10.0.2.2:8000` (o la IP de tu equipo).
> Teléfono físico: debe estar en la **misma red Wi-Fi** que la PC servidor.

---

## 3. Fase 3 — Abstracción de red para usuarios no técnicos

Para que el usuario final **no tenga que teclear IPs ni abrir la consola**.

### Opción A — Demostración remota sin costo (túnel)

En la PC del backend ejecuta (solo instala lo que prefieras):

```bash
# cloudflared (recomendado, sin cuenta):
cloudflared tunnel --url http://localhost:8000

# o ngrok:
ngrok http 8000
```

Copia el enlace HTTPS generado (ej. `https://inventario-demo.trycloudflare.com`)
y colócalo en `config.dart`. El sistema funcionará desde cualquier lugar
con internet, sin tocar el router.

### Opción B — Red local automatizada por nombre (mDNS)

Haz que la PC servidor responda a un nombre como `servidor-inventario.local`.
Así Flutter siempre apuntará a ese nombre aunque el router cambie la IP privada.

**Windows (Avahi/AutoHotkey no necesario):**

1. Instala **Apple Bonjour** (incluye mDNS) o actívalo, o usa
   [mdsn](https://www.h2x.com) — la vía sencilla es instalar
   **Bonjour Print Services** (Apple) que registra y resuelve `.local`.

2. Renombrar el equipo no basta; hay que publicar el servicio. La forma
   práctica sin dependencias extra es instalar **Hostname** de mDNS, p. ej.:

   ```bash
   # en Windows puedes usar el paquete npm "mdns" como servicio, o
   # simplemente reservar el nombre en el router (rendimiento más simple).
   ```

**Linux (avahi):**

```bash
sudo apt install avahi-daemon avahi-utils
# Nombre de equipo .local ya se publica automáticamente.
```

En Flutter (`config.dart`):

```dart
const String apiBaseUrl = 'http://servidor-inventario.local:8000';
```

> Consejo práctico y cero dependencias: **reserva una IP fija** (DHCP
> reservation) en el router y usa la IP — semánticamente idéntico para el
> usuario (nunca cambia), sin mDNS.

---

## 4. Fase 4 — Empaquetado para distribución final

### 4.1 Backend → ejecutable único con PyInstaller

```bash
cd Backend
pip install pyinstaller
pyinstaller --onefile --name inventario-api main.py
```

Resultado: `Backend/dist/inventario-api.exe`.
Se incluye solo el runtime; **no se expone el código fuente**.

> Nota: el `.db` se crea junto al ejecutable en tiempo de ejecución.

### 4.2 Frontend → ejecutable de escritorio

```bash
cd Proyecto_Flutter
flutter build windows
```

> En Flutter 3.47 se usa `flutter build windows` (ver `flutter help build`).
> El binario se genera en `build/windows/...`.

### 4.3 Instalador unificado + lanzamiento del backend

Incluimos:

- `empresa/inventario.iss` — script de **Inno Setup** que instala el
  ejecutable del backend y la app Flutter juntos, y crea un servicio.
- `empresa/inventario-servicio.bat` — script que **levanta el backend en
  segundo plano y en silencio** al iniciar (para usarlo sin servicios).

**Opción servicio de Windows (recomendada):** el `.iss` instala el binario
como servicio con `sc create` para que arranque solo, de forma silenciosa:

```bat
sc create InventarioApi binPath="C:\Program Files\Inventario\inventario-api.exe" start=automatic
sc start InventarioApi
```

Consulta `empresa/LEEME-EMPAQUETADO.md` para el paso a paso de Inno Setup y
cómo enlazar la app Flutter con el proceso del backend.