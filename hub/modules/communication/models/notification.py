from hub.db.database import BaseModel, Field

class DeviceToken(BaseModel):
    __table__ = "device_tokens"
    
    token = Field("TEXT", primary_key=True)
    platform = Field("TEXT", default="android")
    updated_at = Field("TEXT", default="")
    
    def to_dict(self):
        return {
            "token": self.token,
            "platform": self.platform,
            "updated_at": self.updated_at
        }

class NotificationLog(BaseModel):
    __table__ = "notification_logs"
    
    id = Field("INTEGER", primary_key=True)
    ts = Field("TEXT", default="")
    title = Field("TEXT", default="")
    body = Field("TEXT", default="")
    event_type = Field("TEXT", default="info") # 'connected', 'disconnected', 'skill', 'alert'
    device_id = Field("TEXT", default="")
    priority = Field("TEXT", default="high")
    status = Field("TEXT", default="sent")
    
    def to_dict(self):
        return {
            "id": self.id,
            "ts": self.ts,
            "title": self.title,
            "body": self.body,
            "event_type": self.event_type,
            "device_id": self.device_id,
            "priority": self.priority,
            "status": self.status
        }
