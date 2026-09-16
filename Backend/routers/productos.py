"""Rutas CRUD de productos y importación de inventario desde Excel."""
import io
from typing import List

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

import ia_import
import models
import schemas
from database import get_db

router = APIRouter(
    prefix="/api/v1/productos",
    tags=["productos"],
)


# Columnas esperadas en la plantilla de importación.
COLUMNAS_IMPORTACION = ("nombre", "precio", "stock", "categoria", "descripcion")


def _normalizar(valor):
    """Convierte un valor de celda a texto limpio (o "")."""
    if valor is None:
        return ""
    return str(valor).strip()


def _texto_opcional(valor):
    texto = _normalizar(valor)
    return texto if texto else ""


# Las rutas de plantilla/importar deben ir ANTES de /{producto_id} para que
# no sean capturadas por el parámetro de ruta de tipo int.


@router.get("/plantilla")
def obtener_plantilla():
    """Genera un archivo .xlsx de ejemplo con las columnas esperadas."""
    from openpyxl import Workbook
    from openpyxl.styles import Font
    from openpyxl.utils import get_column_letter

    wb = Workbook()
    ws = wb.active
    ws.title = "Inventario"
    encabezados = ["Nombre", "Precio", "Stock", "Categoria", "Descripcion"]
    ws.append(encabezados)
    for celda in ws[1]:
        celda.font = Font(bold=True)
    ejemplo = ["Gaseosa 1L", 35.50, 100, "Bebidas", "Fresca, sabor cola"]
    ws.append(ejemplo)
    for i in range(1, len(encabezados) + 1):
        ws.column_dimensions[get_column_letter(i)].width = 24

    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=plantilla_inventario.xlsx"},
    )


@router.post(
    "/importar",
    response_model=schemas.ProductoImportarResultado,
)
def importar_inventario(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Importa productos desde un .xlsx.

    Columna esperada (la primera fila es el encabezado):
        Nombre | Precio | Stock | Categoria | Descripcion

    Si ya existe un producto con el mismo nombre, se actualizan sus datos.
    """
    from openpyxl import load_workbook

    nombre_archivo = (file.filename or "").lower()
    if not nombre_archivo.endswith((".xlsx", ".xlsm")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe ser .xlsx o .xlsm",
        )

    contenido = file.file.read()
    try:
        wb = load_workbook(io.BytesIO(contenido), read_only=True, data_only=True)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se pudo leer el archivo: {e}",
        )

    ws = wb.active
    filas = ws.iter_rows(values_only=True)
    try:
        encabezados_raw = next(filas)
    except StopIteration:
        encabezados_raw = ()
    if not encabezados_raw:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo está vacío (sin encabezados)",
        )

    # Normalizar encabezados (minúsculas, sin espacios) para tolerar variaciones.
    mapa = {}
    for idx, nombre_col in enumerate(encabezados_raw):
        clave = _normalizar(nombre_col).lower().replace(" ", "")
        if clave:
            mapa[clave] = idx

    faltantes = [c for c in COLUMNAS_IMPORTACION if c not in mapa]
    if faltantes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Faltan las columnas: {', '.join(faltantes)}",
        )

    return _guardar_desde_mapa(mapa=mapa, filas=filas, db=db)


def _guardar_desde_mapa(mapa: dict, filas, db: Session) -> schemas.ProductoImportarResultado:
    """Inserta/actualiza productos usando el mapeo columna->índice.

    `mapa`: dict con clave = campo canónico y valor = índice de la columna.
    `filas`: iterable de filas (de openpyxl, ya sin encabezado).
    """
    importados = 0
    errores = []
    total_filas = 0

    for fila in filas:
        total_filas += 1
        numero_fila = total_filas + 1  # fila 1 = encabezado
        try:
            nombre = _normalizar(fila[mapa["nombre"]])
            if not nombre:
                raise ValueError("Nombre vacío")

            precio_raw = fila[mapa["precio"]]
            stock_raw = fila[mapa["stock"]]
            precio = float(precio_raw) if precio_raw not in (None, "") else 0.0
            stock = int(stock_raw) if stock_raw not in (None, "") else 0

            if precio < 0:
                raise ValueError("Precio negativo")
            if stock < 0:
                raise ValueError("Stock negativo")

            categoria = _texto_opcional(fila[mapa["categoria"]]) if "categoria" in mapa else ""
            descripcion = _texto_opcional(fila[mapa["descripcion"]]) if "descripcion" in mapa else ""

            # Upsert por nombre.
            producto = (
                db.query(models.Producto)
                .filter(models.Producto.nombre == nombre)
                .first()
            )
            if producto:
                producto.precio = precio
                producto.stock = stock
                producto.categoria = categoria
                producto.descripcion = descripcion
            else:
                producto = models.Producto(
                    nombre=nombre,
                    descripcion=descripcion,
                    precio=precio,
                    stock=stock,
                    categoria=categoria,
                )
                db.add(producto)
            importados += 1
        except Exception as e:  # noqa: BLE001 - error por fila, sigue con las demás
            errores.append(
                schemas.ImportarError(fila=numero_fila, error=str(e))
            )

    db.commit()
    return schemas.ProductoImportarResultado(
        importados=importados,
        errores=errores,
        total_filas=total_filas,
    )


def _leer_libro(contenido: bytes):
    """Carga el primer libro activo y devuelve (encabezados, filas)."""
    from openpyxl import load_workbook

    try:
        wb = load_workbook(io.BytesIO(contenido), read_only=True, data_only=True)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se pudo leer el archivo: {e}",
        )
    ws = wb.active
    filas = ws.iter_rows(values_only=True)
    try:
        encabezados = next(filas)
    except StopIteration:
        encabezados = ()
    if not encabezados:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo está vacío (sin encabezados)",
        )
    return wb, ws, encabezados, filas


def _exigir_xlsx(file: UploadFile):
    nombre_archivo = (file.filename or "").lower()
    if not nombre_archivo.endswith((".xlsx", ".xlsm")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe ser .xlsx o .xlsm",
        )


@router.post("/import/preview")
def importar_preview(file: UploadFile = File(...)):
    """Lee el archivo y propone un mapeo de columnas al esquema canónico.

    Si la IA está configurada (GOOGLE_API_KEY) usa Gemini para mapear;
    en caso contrario devuelve un mapeo por coincidencia de nombre exacto.
    """
    _exigir_xlsx(file)
    contenido = file.file.read()
    _wb, _ws, encabezados, filas = _leer_libro(contenido)

    # Muestra de hasta 3 filas para que la IA deduzca el tipo de cada columna.
    muestras = []
    for fila in filas:
        muestras.append(list(fila))
        if len(muestras) >= 3:
            break

    mapeo = {}
    if ia_import.cargar_ia():
        try:
            mapeo = ia_import.mapear_columnas(encabezados, muestras)
        except Exception as e:  # noqa: BLE001
            mapeo = {"_error": f"No se pudo mapear con IA: {e}"}
    else:
        # Fallback: coincidencia por nombre normalizado.
        for idx, col in enumerate(encabezados):
            clave = _normalizar(col).lower().replace(" ", "")
            if clave in COLUMNAS_IMPORTACION:
                mapeo[col] = clave

    return {
        "encabezados": [str(c) for c in encabezados if str(c).strip() != ""],
        "mapeo": mapeo,
        "muestras": muestras,
    }


@router.post(
    "/import/commit",
    response_model=schemas.ProductoImportarResultado,
)
def importar_commit(
    file: UploadFile = File(...),
    mapeo: str = Form(...),
    db: Session = Depends(get_db),
):
    """Importa usando el mapeo columna->campo canónico (confirmado por el usuario).

    `mapeo` es un JSON tipo {"ENCABEZADO": "nombre", ...}.
    """
    import json as _json

    _exigir_xlsx(file)
    try:
        mapeo_aux = _json.loads(mapeo)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"mapeo no es un JSON válido: {e}",
        )

    contenido = file.file.read()
    wb, _ws, encabezados, filas = _leer_libro(contenido)

    # Interpretar mapeo: campo canónico -> índice de columna.
    indices = {}
    for idx, col in enumerate(encabezados):
        campo = mapeo_aux.get(str(col))
        if campo in COLUMNAS_IMPORTACION:
            indices[campo] = idx

    faltantes = [c for c in ("nombre", "precio", "stock") if c not in indices]
    if faltantes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El mapeo no cubre los campos obligatorios: {', '.join(faltantes)}",
        )

    return _guardar_desde_mapa(mapa=indices, filas=filas, db=db)


@router.get("", response_model=List[schemas.ProductoOut])
def listar_productos(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    buscar: str | None = Query(None, description="Filtro por nombre o categoría"),
    db: Session = Depends(get_db),
):
    q = db.query(models.Producto)
    if buscar:
        termino = f"%{buscar}%"
        q = q.filter(
            models.Producto.nombre.ilike(termino)
            | models.Producto.categoria.ilike(termino)
        )
    return q.order_by(models.Producto.nombre).offset(skip).limit(limit).all()


@router.get(
    "/{producto_id}",
    response_model=schemas.ProductoOut,
    responses={404: {"model": schemas.Mensaje}},
)
def obtener_producto(producto_id: int, db: Session = Depends(get_db)):
    producto = db.get(models.Producto, producto_id)
    if not producto:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Producto {producto_id} no encontrado",
        )
    return producto


@router.post(
    "",
    response_model=schemas.ProductoOut,
    status_code=status.HTTP_201_CREATED,
)
def crear_producto(datos: schemas.ProductoCreate, db: Session = Depends(get_db)):
    producto = models.Producto(**datos.model_dump())
    db.add(producto)
    db.commit()
    db.refresh(producto)
    return producto


@router.patch(
    "/{producto_id}",
    response_model=schemas.ProductoOut,
    responses={404: {"model": schemas.Mensaje}},
)
def actualizar_producto(
    producto_id: int,
    datos: schemas.ProductoUpdate,
    db: Session = Depends(get_db),
):
    producto = db.get(models.Producto, producto_id)
    if not producto:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Producto {producto_id} no encontrado",
        )
    cambios = datos.model_dump(exclude_unset=True)
    for campo, valor in cambios.items():
        setattr(producto, campo, valor)
    db.commit()
    db.refresh(producto)
    return producto


@router.delete(
    "/{producto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={404: {"model": schemas.Mensaje}},
)
def eliminar_producto(producto_id: int, db: Session = Depends(get_db)):
    producto = db.get(models.Producto, producto_id)
    if not producto:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Producto {producto_id} no encontrado",
        )
    db.delete(producto)
    db.commit()
    return None