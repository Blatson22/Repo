"""Rutas de reportes: agregados de productos y movimientos.

Todos los reportes aceptan filtros opcionales de rango de fechas y tipo.
Se calculan sobre las tablas `productos`, `documentos` y `documento_lineas`.
"""
from datetime import date, datetime, time, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db

router = APIRouter(
    prefix="/api/v1/reportes",
    tags=["reportes"],
)


def _filtros_fecha(
    fecha_desde: Optional[date],
    fecha_hasta: Optional[date],
    q,
):
    if fecha_desde:
        q = q.filter(models.Documento.fecha >= datetime.combine(fecha_desde, time.min))
    if fecha_hasta:
        q = q.filter(models.Documento.fecha <= datetime.combine(fecha_hasta, time.max))
    return q


@router.get("/resumen", response_model=schemas.ReporteResumen)
def resumen(
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(models.Documento.tipo, func.coalesce(func.sum(models.Documento.total), 0.0))
    q = _filtros_fecha(fecha_desde, fecha_hasta, q)
    q = q.group_by(models.Documento.tipo)
    por_tipo = {tipo: total for tipo, total in q.all()}

    valor_almacen = db.query(
        func.coalesce(func.sum(models.Producto.precio * models.Producto.stock), 0.0)
    ).scalar()
    productos_count = db.query(func.count(models.Producto.id)).scalar()
    compras_count = db.query(func.count(models.Documento.id)).filter(
        models.Documento.tipo == "compra"
    ).scalar()
    ventas_count = db.query(func.count(models.Documento.id)).filter(
        models.Documento.tipo == "venta"
    ).scalar()
    despachos_count = db.query(func.count(models.Documento.id)).filter(
        models.Documento.tipo == "despacho"
    ).scalar()

    return schemas.ReporteResumen(
        total_compras=por_tipo.get("compra", 0.0),
        total_ventas=por_tipo.get("venta", 0.0),
        total_despachos=por_tipo.get("despacho", 0.0),
        valor_almacen=valor_almacen,
        productos_count=productos_count,
        compras_count=compras_count,
        ventas_count=ventas_count,
        despachos_count=despachos_count,
    )


@router.get("/serie", response_model=List[schemas.SerieReporte])
def serie(
    tipo: str = Query(..., description="compra | venta | despacho"),
    agrupar_por: str = Query("dia", pattern="^(dia|mes)$"),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(models.Documento.fecha, models.Documento.total)
    q = q.filter(models.Documento.tipo == tipo)
    q = _filtros_fecha(fecha_desde, fecha_hasta, q)
    docs = q.all()

    grupo: dict[str, dict] = {}
    for fecha_val, total in docs:
        if agrupar_por == "mes":
            clave = fecha_val.strftime("%Y-%m")
        else:
            clave = fecha_val.strftime("%Y-%m-%d")
        g = grupo.setdefault(clave, {"total": 0.0, "count": 0})
        g["total"] += total or 0.0
        g["count"] += 1

    salida = [
        schemas.SerieReporte(fecha=k, total=round(v["total"], 2), count=v["count"])
        for k, v in sorted(grupo.items())
    ]
    return salida


@router.get("/top", response_model=List[schemas.ProductoTop])
def top_productos(
    tipo: str = Query(..., description="venta | despacho"),
    limit: int = Query(10, ge=1, le=100),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    db: Session = Depends(get_db),
):
    q = (
        db.query(
            models.DocumentoLinea.producto_id,
            models.Producto.nombre,
            func.sum(models.DocumentoLinea.cantidad).label("total_cantidad"),
            func.sum(models.DocumentoLinea.subtotal).label("total_importe"),
        )
        .join(models.Producto, models.Producto.id == models.DocumentoLinea.producto_id)
        .join(models.Documento, models.Documento.id == models.DocumentoLinea.documento_id)
        .filter(models.Documento.tipo == tipo)
    )
    q = _filtros_fecha(fecha_desde, fecha_hasta, q)
    rows = (
        q.group_by(
            models.DocumentoLinea.producto_id,
            models.Producto.nombre,
        )
        .order_by(func.sum(models.DocumentoLinea.cantidad).desc())
        .limit(limit)
        .all()
    )
    return [
        schemas.ProductoTop(
            producto_id=r.producto_id,
            nombre=r.nombre,
            total_cantidad=int(r.total_cantidad or 0),
            total_importe=round(r.total_importe or 0.0, 2),
        )
        for r in rows
    ]


@router.get("/movimientos", response_model=List[schemas.MovimientoReporte])
def movimientos(
    producto_id: Optional[int] = Query(None),
    tipo: Optional[str] = Query(None),
    fecha_desde: Optional[date] = Query(None),
    fecha_hasta: Optional[date] = Query(None),
    db: Session = Depends(get_db),
):
    q = (
        db.query(
            models.Documento.id,
            models.Documento.folio,
            models.Documento.tipo,
            models.Documento.fecha,
            models.DocumentoLinea.producto_id,
            models.Producto.nombre,
            models.DocumentoLinea.cantidad,
            models.DocumentoLinea.signo,
            models.DocumentoLinea.precio_unitario,
            models.DocumentoLinea.subtotal,
        )
        .join(models.Documento, models.Documento.id == models.DocumentoLinea.documento_id)
        .join(models.Producto, models.Producto.id == models.DocumentoLinea.producto_id)
    )
    if producto_id:
        q = q.filter(models.DocumentoLinea.producto_id == producto_id)
    if tipo:
        q = q.filter(models.Documento.tipo == tipo)
    q = _filtros_fecha(fecha_desde, fecha_hasta, q)
    rows = q.order_by(models.Documento.fecha.desc()).all()
    return [
        schemas.MovimientoReporte(
            documento_id=r[0],
            folio=r[1],
            tipo=r[2],
            fecha=r[3],
            producto_id=r[4],
            nombre=r[5],
            cantidad=r[6],
            signo=r[7],
            precio_unitario=r[8],
            subtotal=r[9],
        )
        for r in rows
    ]


@router.get("/existencias", response_model=List[schemas.ExistenciaReporte])
def existencias(
    stock_bajo_menor_que: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(models.Producto)
    if stock_bajo_menor_que is not None:
        q = q.filter(models.Producto.stock < stock_bajo_menor_que)
    rows = q.order_by(models.Producto.nombre).all()
    return [
        schemas.ExistenciaReporte(
            producto_id=p.id,
            nombre=p.nombre,
            categoria=p.categoria or "",
            stock=p.stock or 0,
            precio=p.precio or 0.0,
            valor=round((p.precio or 0.0) * (p.stock or 0), 2),
        )
        for p in rows
    ]


@router.get("/valor-almacen")
def valor_almacen(db: Session = Depends(get_db)):
    total = db.query(
        func.coalesce(func.sum(models.Producto.precio * models.Producto.stock), 0.0)
    ).scalar()
    return {"valor_almacen": round(total or 0.0, 2)}