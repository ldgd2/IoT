import hashlib
import os
import time
import json
from hub.db.database import BaseModel, Field, Database


class User(BaseModel):
    __table__ = "users"

    user_id     = Field("TEXT", primary_key=True)
    username    = Field("TEXT", default="")
    email       = Field("TEXT", default="")
    password_hash = Field("TEXT", default="")
    created_at  = Field("TEXT", default="")
    fcm_token   = Field("TEXT", default="")   # Para push notifications

    # ── Helpers ────────────────────────────────────────────────
    @staticmethod
    def _hash_pw(password: str) -> str:
        salt = os.urandom(16).hex()
        h = hashlib.sha256((salt + password).encode()).hexdigest()
        return f"{salt}:{h}"

    @staticmethod
    def _verify_pw(password: str, stored_hash: str) -> bool:
        try:
            salt, h = stored_hash.split(":", 1)
            return hashlib.sha256((salt + password).encode()).hexdigest() == h
        except Exception:
            return False

    # ── CRUD helpers ───────────────────────────────────────────
    @classmethod
    def create(cls, username: str, email: str, password: str) -> "User":
        import uuid
        u = cls(
            user_id=str(uuid.uuid4()),
            username=username,
            email=email,
            password_hash=cls._hash_pw(password),
            created_at=__import__("datetime").datetime.now().isoformat(),
        )
        u.save()
        return u

    @classmethod
    def get_by_email(cls, email: str):
        rows = Database.execute(
            f"SELECT * FROM {cls.__table__} WHERE email = ?", (email,)
        ).fetchall()
        if not rows:
            return None
        return cls(**dict(rows[0]))

    @classmethod
    def get_by_id(cls, user_id: str):
        rows = Database.execute(
            f"SELECT * FROM {cls.__table__} WHERE user_id = ?", (user_id,)
        ).fetchall()
        if not rows:
            return None
        return cls(**dict(rows[0]))

    def verify_password(self, password: str) -> bool:
        return self._verify_pw(password, self.password_hash)

    def to_dict(self):
        return {
            "user_id": self.user_id,
            "username": self.username,
            "email": self.email,
            "created_at": self.created_at,
        }
