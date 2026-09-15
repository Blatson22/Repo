"""Modelo ORM del producto."""
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, Integer, String, Text

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