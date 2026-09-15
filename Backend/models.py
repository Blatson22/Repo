"""Modelos ORM de productos y documentos (compras, ventas, despachos)."""
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from database import Base


class Producto(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(200), nullable=False, index=True)
    descripcion = Column(Text, default="")
    precio = Column(Float, default=0.0)
    stock = Column(Integer, default=0)
    categoria = Column(String(100), default="")
    creado_en = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    actualizado_en = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Producto id={self.id} nombre={self.nombre!r}>"


# Tipos de documento admitidos.
TIPOS_DOCUMENTO = ("compra", "venta", "despacho", "ajuste")


class Documento(Base):
    """Cabecera de un documento (compra / venta / despacho / ajuste)."""

    __tablename__ = "documentos"

    id = Column(Integer, primary_key=True, index=True)
    tipo = Column(String(20), nullable=False, index=True)
    folio = Column(String(50), default="")
    fecha = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    notas = Column(Text, default="")
    total = Column(Float, default=0.0)
    creado_en = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    lineas = relationship(
        "DocumentoLinea",
        back_populates="documento",
        cascade="all, delete-orphan",
        order_by="DocumentoLinea.id",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Documento id={self.id} tipo={self.tipo!r}>"


class DocumentoLinea(Base):
    """Línea de detalle de un documento."""

    __tablename__ = "documento_lineas"

    id = Column(Integer, primary_key=True, index=True)
    documento_id = Column(
        Integer, ForeignKey("documentos.id", ondelete="CASCADE"), nullable=False
    )
    producto_id = Column(Integer, ForeignKey("productos.id"), nullable=False)
    cantidad = Column(Integer, default=1, nullable=False)
    precio_unitario = Column(Float, default=0.0)
    subtotal = Column(Float, default=0.0)
    signo = Column(Integer, default=1)  # +1 entrada (compra), -1 salida (venta/despacho)

    documento = relationship("Documento", back_populates="lineas")
    producto = relationship("Producto")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<DocumentoLinea id={self.id} "
            f"documento={self.documento_id} producto={self.producto_id}>"
        )