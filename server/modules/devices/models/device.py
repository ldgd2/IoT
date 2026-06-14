from server.db.database import BaseModel, Field

class Device(BaseModel):
    __table__ = "devices"
    
    device_id = Field("TEXT", primary_key=True)
    name = Field("TEXT", default="Unknown")
    device_type = Field("TEXT", default="generic")
    status = Field("TEXT", default="offline")
    state = Field("TEXT", default={})
    last_seen = Field("TEXT", default="")
    rssi = Field("INTEGER", default=0)
    msg_count = Field("INTEGER", default=0)

    def update(self, payload: dict, rssi: int = None):
        self.state = payload
        import datetime
        self.last_seen = datetime.datetime.now().isoformat()
        self.status = "online"
        if rssi is not None:
            self.rssi = rssi
        self.msg_count += 1
        self.save()
