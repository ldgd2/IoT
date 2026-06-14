from sqlalchemy import Column, Integer, String, Boolean, DateTime
import datetime
from server.core.database import Base

class Device(Base):
    """
    Representa un nodo de la Colmena conectado.
    """
    __tablename__ = "dev_devices"
    
    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(Integer, unique=True, index=True, nullable=False) # El ID de RF24Mesh (1-255)
    type_id = Column(Integer, nullable=False) # FK logica a cap_device_types.type_id
    
    name = Column(String(100), default="Dispositivo Nuevo")
    is_online = Column(Boolean, default=True)
    last_seen = Column(DateTime, default=datetime.datetime.utcnow)
