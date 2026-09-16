"""Rutas de documentos (compras, ventas, despachos, ajustes).

Al crear un documento con sus líneas se ajusta el stock de cada producto
según el signo del tipo (compra = entrada, venta/despacho = salida).
Las salidas pueden dejar stock negativo; en ese caso se devuelve una lista
de avisos sin bloquear la operación.
"""
from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db

router = APIRouter(
    prefix="/api/v1/documentos",
    tags=["documentos"],
)

# signo por tipo: compra=+1 (entrada), venta/despacho=-1 (salida)
_SIGNO_TIPO = {
    "compra": 1,
    "venta": -1,
    "despacho": -1,
    "ajuste": 1,  # el ajuste usa el signo según lo indique el cliente (campo signo de línea)
}


def _aplicar_stock(db: Session, doc: models.Documento):
    """Ajusta el stock de los productos según las líneas del documento."""
    for linea in doc.lineas:
        producto = db.get(models.Producto, linea.producto_id)
        if not producto:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Producto {linea.producto_id} no existe",
            )
        signo = _SIGNO_TIPO.get(doc.tipo, 1)
        if doc.tipo == "ajuste":
            signo = linea.signo
        producto.stock = (producto.stock or 0) + signo * linea.cantidad


def _revertir_stock(db: Session, doc: models.Documento):
    """Deshace el efecto de un documento sobre el stock de sus productos."""
    for linea in doc.lineas:
        producto = db.get(models.Producto, linea.producto_id)
        if not producto:
            continue
        signo = _SIGNO_TIPO.get(doc.tipo, 1)
        if doc.tipo == "ajuste":
            signo = linea.signo
        producto.stock = (producto.stock or 0) - signo * linea.cantidad


def _calcular_totales(doc: models.Documento, db: Session):
    """Recalcula subtotales y total del documento según el precio de cada línea."""
    total = 0.0
    for linea in doc.lineas:
        linea.subtotal = linea.cantidad * linea.precio_unitario
        total += linea.subtotal
    doc.total = round(total, 2)


def _avisos_negativos(doc: models.Documento, db: Session) -> List[str]:
    """Devuelve avisos cuando una salida deja el stock en negativo."""
    avisos: List[str] = []
    saliente = doc.tipo in ("venta", "despacho")
    if not saliente:
        return avisos
    for linea in doc.lineas:
        producto = db.get(models.Producto, linea.producto_id)
        if producto and (producto.stock or 0) < 0:
            avisos.append(
                f"El producto '{producto.nombre}' quedó con stock {producto.stock} "
                f"(menor a 0)."
            )
    return avisos


@router.get(
    "",
    response_model=dict,
    responses={404: {"model": schemas.Mensaje}},
)
def listar_documentos(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    tipo: str | None = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(models.Documento)
    if tipo:
        q = q.filter(models.Documento.tipo == tipo)
    docs = q.order_by(models.Documento.fecha.desc()).offset(skip).limit(limit).all()
    return {
        "total": len(docs),
        "items": [schemas.DocumentoOut.model_validate(d).model_dump() for d in docs],
    }


@router.get(
    "/{documento_id}",
    response_model=schemas.DocumentoOut,
    responses={404: {"model": schemas.Mensaje}},
)
def obtener_documento(documento_id: int, db: Session = Depends(get_db)):
    doc = db.get(models.Documento, documento_id)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Documento {documento_id} no encontrado",
        )
    return doc


@router.post(
    "",
    response_model=schemas.DocumentoCreado,
    status_code=status.HTTP_201_CREATED,
)
def crear_documento(datos: schemas.DocumentoCreate, db: Session = Depends(get_db)):
    doc = models.Documento(
        tipo=datos.tipo,
        folio=datos.folio or "",
        fecha=datos.fecha or datetime.now(timezone.utc),
        notas=datos.notas or "",
    )
    for linea_in in datos.lineas:
        producto = db.get(models.Producto, linea_in.producto_id)
        if not producto:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Producto {linea_in.producto_id} no existe",
            )
        doc.lineas.append(
            models.DocumentoLinea(
                producto_id=linea_in.producto_id,
                cantidad=linea_in.cantidad,
                precio_unitario=linea_in.precio_unitario,
                signo=_SIGNO_TIPO.get(datos.tipo, 1),
            )
        )
    _calcular_totales(doc, db)
    db.add(doc)
    db.flush()
    _aplicar_stock(db, doc)
    avisos = _avisos_negativos(doc, db)
    db.commit()
    db.refresh(doc)
    salida = schemas.DocumentoCreado.model_validate(doc).model_dump()
    salida["avisos"] = avisos
    return salida


@router.patch(
    "/{documento_id}",
    response_model=schemas.DocumentoCreado,
    responses={404: {"model": schemas.Mensaje}},
)
def actualizar_documento(
    documento_id: int,
    datos: schemas.DocumentoUpdate,
    db: Session = Depends(get_db),
):
    doc = db.get(models.Documento, documento_id)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Documento {documento_id} no encontrado",
        )
    _revertir_stock(db, doc)
    cambios = datos.model_dump(exclude_unset=True)
    for campo, valor in cambios.items():
        setattr(doc, campo, valor)
    _calcular_totales(doc, db)
    db.add(doc)
    db.flush()
    _aplicar_stock(db, doc)
    avisos = _avisos_negativos(doc, db)
    db.commit()
    db.refresh(doc)
    salida = schemas.DocumentoCreado.model_validate(doc).model_dump()
    salida["avisos"] = avisos
    return salida


@router.delete(
    "/{documento_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={404: {"model": schemas.Mensaje}},
)
def eliminar_documento(documento_id: int, db: Session = Depends(get_db)):
    doc = db.get(models.Documento, documento_id)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Documento {documento_id} no encontrado",
        )
    _revertir_stock(db, doc)
    db.delete(doc)
    db.commit()
    return None


@router.get("/tipos", response_model=schemas.TipoDocumento)
def tipos_documento():
    return {"tipos": list(models.TIPOS_DOCUMENTO)}