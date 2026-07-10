from hub.db.database import BaseModel, Field, Database


class Room(BaseModel):
    __table__ = "rooms"

    room_id    = Field("TEXT", primary_key=True)
    user_id    = Field("TEXT", default="")
    name       = Field("TEXT", default="")
    icon       = Field("TEXT", default="home")
    created_at = Field("TEXT", default="")

    @classmethod
    def create(cls, user_id: str, name: str, icon: str = "home") -> "Room":
        import uuid, datetime
        r = cls(
            room_id=str(uuid.uuid4()),
            user_id=user_id,
            name=name,
            icon=icon,
            created_at=datetime.datetime.now().isoformat(),
        )
        r.save()
        return r

    @classmethod
    def get_by_user(cls, user_id: str):
        rows = Database.execute(
            f"SELECT * FROM {cls.__table__} WHERE user_id = ? ORDER BY created_at ASC",
            (user_id,)
        ).fetchall()
        return [cls(**dict(r)) for r in rows]

    @classmethod
    def get_by_id(cls, room_id: str):
        rows = Database.execute(
            f"SELECT * FROM {cls.__table__} WHERE room_id = ?", (room_id,)
        ).fetchall()
        if not rows:
            return None
        return cls(**dict(rows[0]))

    def to_dict(self):
        return {
            "room_id": self.room_id,
            "user_id": self.user_id,
            "name": self.name,
            "icon": self.icon,
            "created_at": self.created_at,
        }
