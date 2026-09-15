"""Levanta el servidor real (uvicorn 0.0.0.0:8000), hace peticiones y lo detiene."""
import json
import os
import subprocess
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8000"

# Inicia el servidor real como subproceso
proc = subprocess.Popen(
    [sys.executable, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"],
    cwd=os.path.dirname(os.path.abspath(__file__)),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
ok = True

def check(name, cond):
    global ok
    print(f"[{'OK' if cond else 'FALLO'}] {name}")
    if not cond:
        ok = False

def req(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    if data:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r, timeout=10) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        return e.code, json.loads(raw) if raw else None

# Esperar a que el servidor arranque
for _ in range(30):
    try:
        req("GET", "/health")
        break
    except Exception:
        time.sleep(0.5)
else:
    out, _ = proc.communicate(timeout=2)
    print("No arrancó el servidor:\n", out.decode())
    sys.exit(1)

try:
    s, _ = req("GET", "/health")
    check("HEALTH", s == 200)

    nuevo = {"nombre": "Laptop HP", "precio": 850.5, "stock": 4, "categoria": "Electrónica"}
    s, data = req("POST", "/api/v1/productos", nuevo)
    check("CREAR -> 201", s == 201)
    pid = data["id"]

    s, data = req("GET", f"/api/v1/productos/{pid}")
    check("OBTENER -> 200", s == 200 and data["nombre"] == "Laptop HP")

    s, _ = req("POST", "/api/v1/productos", {"nombre": "Mouse", "precio": 15, "stock": 20})
    check("CREAR 2º -> 201", s == 201)

    s, data = req("GET", "/api/v1/productos")
    check("LISTADO = 2", s == 200 and len(data) == 2)

    s, data = req("PATCH", f"/api/v1/productos/{pid}", {"stock": 10})
    check("PATCH -> 200", s == 200 and data["stock"] == 10)

    s, _ = req("DELETE", f"/api/v1/productos/{pid}")
    check("DELETE -> 204", s == 204)

    s, _ = req("GET", f"/api/v1/productos/{pid}")
    check("GET tras DELETE -> 404", s == 404)
finally:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()

print("\nRESULTADO:", "TODAS LAS PRUEBAS PASARON" if ok else "HUBO FALLOS")
sys.exit(0 if ok else 1)