from hub.db.database import BaseModel, Field

class Device(BaseModel):
    __table__ = "devices"
    
    device_id = Field("TEXT", primary_key=True)
    name = Field("TEXT", default="Unknown")
    type_code = Field("INTEGER", default=0)
    type_name = Field("TEXT", default="generic")
    type_icon = Field("TEXT", default="help-circle.svg")
    category = Field("TEXT", default="system")
    features = Field("INTEGER", default=0)
    feature_keys = Field("TEXT", default=[])
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
