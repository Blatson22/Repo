"""Punto de entrada de la API de inventario.

Ejecutar con:
    python main.py

El servidor escucha en 0.0.0.0:8000 para aceptar conexiones externas
(PC de gama baja en LAN, o túnel cloudflared/ngrok).
"""
import sys

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import models
from database import Base, engine
from routers import documentos, exportar, productos, reportes

# Crea las tablas si no existen.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API de Inventario",
    description="CRUD de productos, documentos (compras/ventas/despachos) y reportes.",
    version="1.1.0",
)

# CORS abierto: la app Flutter puede correr en distintos orígenes
# (web, dispositivo móvil) durante desarrollo/despliegue.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(productos.router)
app.include_router(documentos.router)
app.include_router(reportes.router)
app.include_router(exportar.router)


@app.get("/")
def raiz():
    return {
        "aplicacion": "API de Inventario",
        "docs": "/docs",
        "endpoints": [
            "/api/v1/productos",
            "/api/v1/documentos",
            "/api/v1/reportes",
            "/api/v1/exportar/reportes",
        ],
    }


@app.get("/health")
def health():
    return {"estado": "ok"}


if __name__ == "__main__":
    # En modo congelado (PyInstaller) no usamos el recargador: debe correr
    # como un único proceso estable (adecuado para servicio de Windows).
    congelado = getattr(sys, "frozen", False)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=not congelado)