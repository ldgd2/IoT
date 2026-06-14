from sqlalchemy import Column, Integer, String, JSON
from server.core.database import Base

class DeviceType(Base):
    """
    Catálogo de Capacidades de los dispositivos.
    Asocia el tipo de hardware numerico (Ej: 2) con un JSON Schema completo
    que define qué acciones, estados y configuraciones tiene.
    """
    __tablename__ = "cap_device_types"
    
    id = Column(Integer, primary_key=True, index=True)
    type_id = Column(Integer, unique=True, index=True, nullable=False) # El uint8_t de C++ (Ej: 2)
    name = Column(String(50), nullable=False) # Ej: "Foco Inteligente"
    description = Column(String(200))
    
    # JSON Schema que define "states" y "actions"
    # Ej: {"states": {"power": "boolean"}, "actions": {"encender": {"cmd_id": 1}}}
    capabilities_json = Column(JSON, nullable=False, default={})
