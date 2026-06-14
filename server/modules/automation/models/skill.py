from server.db.database import BaseModel, Field

class Skill(BaseModel):
    __table__ = "skills"
    
    id = Field("INTEGER", primary_key=True)
    name = Field("TEXT", default="Nueva Skill")
    ast_json = Field("TEXT", default={})
    is_active = Field("INTEGER", default=1)
    created_at = Field("TEXT", default="")
