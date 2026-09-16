# Guía de despliegue del backend en Render (PaaS)

Este documento explica, paso a paso y dirigido a alguien que **nunca ha usado
Render**, cómo subir el backend (`Backend/`) a la nube y conectarlo con el
frontend Flutter.

El repositorio ya incluye un archivo `render.yaml` (BluePrint) que hace casi
todo automático. Recomendado usar ese método.

> Nota sobre el `render.yaml`: en la especificación de Blueprints de Render, la
> base de datos PostgreSQL se declara en la lista raíz `databases:` (NO como un
> servicio con `type: postgres`). Si usas la versión anterior con
> `type: postgres`, Render muestra el error *unknown type "postgres"*.

---

## 0. Requisitos previos

- Cuenta de GitHub (la tienes: `Blatson22`).
- El código ya subido a `main` en el repo `Blatson22/Repo` (esta guía
  parte de que los cambios ya fueron pusheados).

> Crear una cuenta en Render es gratis y no pide tarjeta de crédito:
> <https://render.com> → **Sign Up** (puedes entrar con tu cuenta de GitHub).

---

## 1. Método recomendado: usar el archivo `render.yaml` (BluePrint)

1. En el panel de Render, clic en **New + → Blueprint**.
2. Conecta tu GitHub (si te lo pide) y selecciona el repo `Blatson22/Repo`.
3. Elige la rama `main`.
4. Render leerá `render.yaml` y mostrará dos recursos a crear:
   - **Web Service** `inventario-api` (la API FastAPI).
   - **PostgreSQL** `inventario-db` (la base de datos).
5. Clic en **Apply** (confirmar la creación).

Render crea automáticamente el Web Service y la base, e inyecta la variable
`DATABASE_URL` dentro del servicio. No hay que configurar nada a mano.

---

## 2. Método manual (por si no usas BluePrint)

### 2.1 Crear el Web Service
1. **New + → Web Service**.
2. Conecta GitHub y selecciona `Blatson22/Repo`, rama `main`.
3. Configura:
   - **Name:** `inventario-api`
   - **Environment:** `Python 3`
   - **Root Directory:** `Backend`  ← importa apuntar a esta carpeta
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type:** `Free`
4. **Create Web Service**.

### 2.2 Crear la base de datos PostgreSQL
1. **New + → PostgreSQL**.
2. **Name:** `inventario-db` · **Plan:** `Free` · **Create Database**.
3. Copia la **Internal Database URL** que te muestra Render.

### 2.3 Conectar la BD al servicio
1. En tu Web Service → pestaña **Environment → Add Environment Variable**.
2. **Key:** `DATABASE_URL` · **Value:** pega la *Internal Database URL*.
3. **Save Changes** (provoca un redeploy automático).

> Usa la **Internal**, no la *Public*, porque ambos recursos viven en la red
> privada de Render. La base se crea **vacía** a propósito.

---

## 3. Comprobar que funciona

- Espera a que el Web Service pase a estado **Live** (verde).
- Prueba desde el navegador:

  | Ruta | Qué esperas |
  |------|-------------|
  | `https://inventario-api-z6a9.onrender.com/health` | `{"estado":"ok"}` |
  | `https://inventario-api-z6a9.onrender.com/docs` | Documentación Swagger interactiva |

- Dentro de `/docs` puedes probar el endpoint de importación:
  **POST `/api/v1/productos/importar`** (sube un `.xlsx`) y
  **GET `/api/v1/productos/plantilla`** (descarga la plantilla de ejemplo).

---

## 4. Apuntar la app Flutter a Render

1. Abre `Proyecto_Flutter/lib/config.dart`.
2. La variable quedaría así (ajújala si tu Web Service se llama distinto):

   ```dart
   const String apiBaseUrl = 'https://inventario-api-z6a9.onrender.com';
   ```

3. Recompila y relanza la app. Ahora consume la API desde la nube.

---

## 5. Notas y recomendaciones

- **Plan gratuito y "sueño":** los Web Services gratis se apagan tras unos 30
  minutos de inactividad. La primera petición después de dormirse tarda unos
  30 segundos en responder; luego todo va rápido. No es un fallo.
- **Persistencia:** los datos viven en PostgreSQL, así que no se pierden al
  redeployar (a diferencia de un SQLite local).
- **CORS:** ya está abierto (`allow_origins=["*"]`), así que la app Flutter web
  y de escritorio funcionan sin cambios extra.

---

## 6. Re-despliegue tras cambios

Cada vez que hagas `push` a `main`, Render redepliega solo. Comando típico:

```bash
git add -A
git commit -m "descripción del cambio"
git push origin main
```