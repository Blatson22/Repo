import io
import os

from fastapi.testclient import TestClient

import main as app_main

client = TestClient(app_main.app)
RUTA = r"C:\Users\Blats\AppData\Local\Temp\opencode\bacos.xlsx"


def test_preview_ia():
    with open(RUTA, "rb") as f:
        r = client.post(
            "/api/v1/productos/import/preview",
            files={"file": ("bacos.xlsx", f, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        )
    print("preview HTTP", r.status_code)
    print(r.text)
    assert r.status_code == 200
    data = r.json()
    mapeo = data.get("mapeo", {})
    # El mapeo puede venir con _error si la IA falla.
    if "_error" in mapeo:
        print("ERROR IA:", mapeo["_error"])
        return
    print("mapeo:", mapeo)


def test_commit():
    # mapeo manual (como confirmaría el usuario tras ver el preview)
    mapeo = {
        "PRODUCTO": "nombre",
        "PRECIO UNITARIO VENTA": "precio",
        "EXISTENCIA": "stock",
        "CATEGORIA": "categoria",
        "CODIGO": "codigo",
        "COSTO UNITARIO": None,
    }
    with open(RUTA, "rb") as f:
        r = client.post(
            "/api/v1/productos/import/commit",
            data={"mapeo": __import__("json").dumps(mapeo)},
            files={"file": ("bacos.xlsx", f, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        )
    print("commit HTTP", r.status_code)
    print(r.text)
    assert r.status_code == 200
    data = r.json()
    assert data["importados"] == 3, data


if __name__ == "__main__":
    print("GOOGLE_API_KEY set:", bool(os.getenv("GOOGLE_API_KEY")))
    test_preview_ia()
    test_commit()