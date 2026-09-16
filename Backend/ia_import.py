"""Mapeo inteligente de columnas de un archivo de inventario usando Gemini.

Filosofía de diseño:
    - La IA solo lee los ENCABEZADOS + unas pocas filas de muestra y devuelve
      un JSON que dice a qué campo canónico corresponde cada columna.
    - La inserción real de filas se hace luego con código tradicional
      (ver productos.py), sin IA, para mantener el costo bajo y cero errores.

Esquema canónico al que se mapea:
    nombre, precio, stock, categoria, descripcion, codigo
"""
import json
import os
from typing import List, Sequence

# Campos obligatorios / conocidos del esquema canónico de importación.
CAMPOS_CANONICOS = ("nombre", "precio", "stock", "categoria", "descripcion", "codigo")
CAMPOS_OBLIGATORIOS = ("nombre",)
# Campos que se guardan en la BD (codigo no se persiste por ahora).
CAMPOS_PERSISTIBLES = ("nombre", "precio", "stock", "categoria", "descripcion")


def cargar_ia() -> bool:
    """Devuelve True si la IA está configurada (API key presente)."""
    return bool(os.getenv("GOOGLE_API_KEY", "").strip())


def _filtro_acceso(encabezados: Sequence) -> List[str]:
    import os

    api_key = os.getenv("GOOGLE_API_KEY", "").strip()
    if not api_key:
        return encabezados
    return encabezados


def mapear_columnas(encabezados: Sequence, filas_muestra: Sequence) -> dict:
    """Pide a Gemini que mapee las columnas del archivo al esquema canónico.

    Raises:
        RuntimeError: si no hay API key o la llamada falla.
    """
    from google import genai
    from google.genai import types

    api_key = os.getenv("GOOGLE_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("GOOGLE_API_KEY no está configurada")

    modelo = os.getenv("GOOGLE_AI_MODEL", "gemini-flash-lite-latest").strip()

    enc_limpios = [str(c) for c in encabezados if str(c).strip() != ""]

    prompt = f"""
Eres un asistente que interpreta encabezados de tablas de inventario.

Un proveedor subió un archivo con estos encabezados de columna:
{json.dumps(enc_limpios, ensure_ascii=False)}

Y estas son 3 filas de ejemplo (valores para que deduzcas cuáles son:
nombre, precio, stock, categoria, descripcion, codigo):
{json.dumps(filas_muestra, ensure_ascii=False)}

Mapea cada encabezado al campo canónico que mejor corresponda.
Los campos canónicos válidos son:
- "nombre"      (el nombre del producto)
- "precio"      (el precio DE VENTA del producto)
- "stock"       (la cantidad existente)
- "categoria"   (la categoría del producto)
- "descripcion" (descripción)
- "codigo"      (código/SKU del producto, solo si hay columna clara de código)

Reglas estrictas:
1. Devuelve ÚNICAMENTE un objeto JSON válido, sin texto alrededor, sin
   comillas de código markdown, sin comentarios.
2. La clave de cada entrada del JSON debe ser el encabezado EXACTO tal como
   está en la lista de encabezados (con sus espacios y mayúsculas originales).
3. Si un encabezado no corresponde a ningún campo canónico, inclúyelo con
   valor null (por ejemplo costos, margen, notas de proveedor, etc.).
4. No inventes encabezados que no existan.
5. Prioriza PRECIO DE VENTA cuando exista más de una columna de precio;
   las columnas de costo irán como null.

Ejemplo de salida:
{{"CODIGO": "codigo", "PRODUCTO": "nombre", "PRECIO UNITARIO VENTA": "precio",
  "EXISTENCIA": "stock", "COSTO UNITARIO": null}}
"""
    client = genai.Client(api_key=api_key)
    respuesta = client.models.generate_content(
        model=modelo,
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.0,
            response_mime_type="application/json",
        ),
    )

    try:
        texto = respuesta.text.strip()
        # Quita posibles cercos de código markdown por seguridad.
        if texto.startswith("```"):
            texto = texto.strip("`")
            if texto.startswith("json"):
                texto = texto[4:]
        mapeo = json.loads(texto)
    except Exception as e:
        raise RuntimeError(f"No se pudo interpretar el mapeo de la IA: {e}") from e

    if not isinstance(mapeo, dict):
        raise RuntimeError("La IA no devolvió un objeto de mapeo válido")

    # Filtra a encabezados reales y campos canónicos válidos.
    validos = {c: mapeo.get(c) for c in enc_limpios}
    validos = {
        k: (v if v in CAMPOS_CANONICOS else None)
        for k, v in validos.items()
    }
    return validos