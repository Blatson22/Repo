"""Esquemas Pydantic para validación de entrada/salida de la API."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field

from models import TIPOS_DOCUMENTO


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


class TipoDocumento(BaseModel):
    tipos: List[str]

    model_config = ConfigDict(from_attributes=True)


class OrigenesDocumento(BaseModel):
    tipo: str


class DocumentoLineaIn(BaseModel):
    producto_id: int = Field(..., gt=0)
    cantidad: int = Field(1, gt=0)
    precio_unitario: float = Field(0.0, ge=0)


class DocumentoCreate(BaseModel):
    tipo: str = Field(..., pattern="|".join(TIPOS_DOCUMENTO))
    folio: Optional[str] = ""
    fecha: Optional[datetime] = None
    notas: Optional[str] = ""
    lineas: List[DocumentoLineaIn] = Field(..., min_length=1)


class DocumentoUpdate(BaseModel):
    """Campos opcionales: solo se actualizan los enviados."""

    folio: Optional[str] = None
    fecha: Optional[datetime] = None
    notas: Optional[str] = None


class DocumentoLineaOut(DocumentoLineaIn):
    id: int
    subtotal: float
    signo: int

    model_config = ConfigDict(from_attributes=True)


class DocumentoOut(BaseModel):
    id: int
    tipo: str
    folio: str
    fecha: datetime
    notas: str
    total: float
    creado_en: datetime
    lineas: List[DocumentoLineaOut]

    model_config = ConfigDict(from_attributes=True)


class DocumentoCreado(DocumentoOut):
    avisos: List[str] = []


class ItemReporte(BaseModel):
    """Fila genérica de un reporte: etiqueta + valor."""

    concepto: str
    importe: float


class ReporteResumen(BaseModel):
    total_compras: float
    total_ventas: float
    total_despachos: float
    valor_almacen: float
    productos_count: int
    compras_count: int
    ventas_count: int
    despachos_count: int


class SerieReporte(BaseModel):
    """Serie temporal: fecha y su valor."""

    fecha: str
    total: float
    count: int


class ProductoTop(BaseModel):
    producto_id: int
    nombre: str
    total_cantidad: int
    total_importe: float


class MovimientoReporte(BaseModel):
    """Movimiento individual de stock derivado de un documento."""

    documento_id: int
    folio: str
    tipo: str
    fecha: datetime
    producto_id: int
    nombre: str
    cantidad: int
    signo: int
    precio_unitario: float
    subtotal: float


class ExistenciaReporte(BaseModel):
    producto_id: int
    nombre: str
    categoria: str
    stock: int
    precio: float
    valor: float