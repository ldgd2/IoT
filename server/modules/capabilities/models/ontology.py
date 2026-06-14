from sqlalchemy import Column, Integer, String, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from server.core.database import Base

class DeviceType(Base):
    """
    Registra el tipo de hardware numerico que envia la placa de C++
    Ej: type_id = 2, name = "Enchufe Inteligente"
    """
    __tablename__ = "cap_device_types"
    
    id = Column(Integer, primary_key=True, index=True)
    type_id = Column(Integer, unique=True, index=True, nullable=False) # El uint8_t de C++
    name = Column(String(50), nullable=False)
    description = Column(String(200))
    
    actions = relationship("DeviceAction", back_populates="device_type", cascade="all, delete-orphan")
    state_vars = relationship("DeviceStateVar", back_populates="device_type", cascade="all, delete-orphan")

class DeviceAction(Base):
    """
    Mapeo Humano-Maquina de Comandos
    Ej: command_id = 0x01, human_name = "encender"
    """
    __tablename__ = "cap_device_actions"
    
    id = Column(Integer, primary_key=True, index=True)
    device_type_id = Column(Integer, ForeignKey("cap_device_types.id"), nullable=False)
    
    command_id = Column(Integer, nullable=False) # El uint8_t command de C++ (ej 0x01)
    human_name = Column(String(50), nullable=False) # ej: "encender"
    requires_data = Column(Boolean, default=False) # Si necesita argumentos (ej RGB data[4])
    
    device_type = relationship("DeviceType", back_populates="actions")

class DeviceStateVar(Base):
    """
    Variables expuestas por un dispositivo para condicionales
    Ej: "humedad", "estado_rele"
    """
    __tablename__ = "cap_device_state_vars"
    
    id = Column(Integer, primary_key=True, index=True)
    device_type_id = Column(Integer, ForeignKey("cap_device_types.id"), nullable=False)
    
    var_name = Column(String(50), nullable=False) # ej: "estado_rele"
    data_type = Column(String(20), default="integer") # boolean, float, integer, string
    
    device_type = relationship("DeviceType", back_populates="state_vars")
