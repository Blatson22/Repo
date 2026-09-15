"""Rutas CRUD de productos."""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db

router = APIRouter(
    prefix="/api/v1/productos",
    tags=["productos"],
)


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