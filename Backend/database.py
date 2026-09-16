"""Configuración de la base de datos vía SQLAlchemy.

Usa PostgreSQL si la variable de entorno DATABASE_URL está definida (Render),
y SQLite en caso contrario (desarrollo local / PC de gama baja).
"""
import os
import sys

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

if DATABASE_URL:
    # En Render conectamos a la PostgreSQL gestionada.
    SQLALCHEMY_DATABASE_URL = DATABASE_URL
    connect_args = {}
else:
    # Desarrollo local: SQLite.
    # Directorio donde se guarda la BD.
    # - Código normal ....... junto al script.
    # - Ejecutable (PyInstaller) .... junto al .exe (con __file__ apunta a un
    #   directorio temporal que se limpia al salir; por eso usamos sys.executable).
    if getattr(sys, "frozen", False):
        BASE_DIR = os.path.dirname(os.path.abspath(sys.executable))
    else:
        BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    DB_PATH = os.path.join(BASE_DIR, "inventario.db")
    SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"
    # connect_args es necesario para poder compartir la conexión entre hilos
    # (FastAPI ejecuta endpoints en un threadpool).
    connect_args = {"check_same_thread": False}

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependencia de FastAPI para obtener una sesión de BD por request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()