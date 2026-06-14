import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Configuración de SQLite
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "colmena.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"

# Configurar el motor de base de datos
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base para que hereden los modelos
Base = declarative_base()

def init_db():
    """Crea todas las tablas en la base de datos."""
    import server.modules.capabilities.models.ontology
    import server.modules.devices.models.device
    import server.modules.automation.models.skill
    Base.metadata.create_all(bind=engine)

def get_db():
    """Generador para dependencias de sesion."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
