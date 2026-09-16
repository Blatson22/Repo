// Configuración global de la aplicación.
library;

/// Esta es la ÚNICA variable que cambia según dónde esté desplegada la API:
///
///  * Desarrollo local ......... http://127.0.0.1:8000
///  * PC de gama baja (LAN) .... http://192.168.1.15:8000  (usa la IP privada real)
///  * Red local por nombre ..... http://servidor-inventario.local:8000  (mDNS)
///  * Demostración remota ...... https://nombre-de-ejemplo.trycloudflare.com  (túnel)
///
/// La URL debe terminar SIN barra al final (ej. `.../8000`, no `.../8000/`).

/// URL ACTUAL del backend desplegado en Render (Web Service).
/// Funciona desde cualquier lugar con internet.
const String apiBaseUrl = 'https://inventario-api-z6a9.onrender.com';