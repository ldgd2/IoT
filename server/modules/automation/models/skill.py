from sqlalchemy import Column, Integer, String, JSON, Boolean
from server.core.database import Base

class Skill(Base):
    """
    Almacena el JSON AST completo (Pseint) de la rutina.
    """
    __tablename__ = "auto_skills"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(String(255))
    is_active = Column(Boolean, default=True)
    
    # JSON logic (El arbol AST que evalua el Engine)
    ast_logic = Column(JSON, nullable=False) 
