"""Esquemas Pydantic para validación de entrada/salida de la API."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ProductoBase(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=200)
    descripcion: Optional[str] = ""
    precio: float = Field(0.0, ge=0)
    stock: int = Field(0, ge=0)
    categoria: Optional[str] = ""


class ProductoCreate(ProductoBase):
    pass


class ProductoUpdate(BaseModel):
    """Todos los campos son opcionales: solo se actualizan los enviados."""

    nombre: Optional[str] = Field(None, min_length=1, max_length=200)
    descripcion: Optional[str] = None
    precio: Optional[float] = Field(None, ge=0)
    stock: Optional[int] = Field(None, ge=0)
    categoria: Optional[str] = None


class ProductoOut(ProductoBase):
    id: int
    creado_en: datetime
    actualizado_en: datetime

    model_config = ConfigDict(from_attributes=True)


class Mensaje(BaseModel):
    detalle: str