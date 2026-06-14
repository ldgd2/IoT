from server.db.database import BaseModel, Field

class RFLog(BaseModel):
    __table__ = "rf_logs"
    
    # INTEGER PRIMARY KEY en SQLite funciona como AUTOINCREMENT si no le pasamos valor
    id = Field("INTEGER", primary_key=True)
    ts = Field("TEXT", default="")
    device_id = Field("TEXT", default="")
    rssi = Field("INTEGER", default=0)
    payload = Field("TEXT", default={})
    direction = Field("TEXT", default="RX")
    cmd = Field("TEXT", default="")
