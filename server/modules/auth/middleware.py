"""
server/modules/auth/middleware.py
JWT liviano con stdlib (hmac + base64). Sin dependencias externas.
"""
import base64
import hashlib
import hmac
import json
import os
import time
from functools import wraps
from flask import request, jsonify, g

_SECRET = os.getenv("JWT_SECRET", "colmena_server_jwt_secret_2026_change_me")
_TTL    = int(os.getenv("JWT_TTL_SECONDS", 60 * 60 * 24 * 30))  # 30 días


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def _unb64(s: str) -> bytes:
    pad = 4 - len(s) % 4
    return base64.urlsafe_b64decode(s + "=" * (pad % 4))

def generate_token(user_id: str) -> str:
    header  = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64(json.dumps({"sub": user_id, "iat": int(time.time()), "exp": int(time.time()) + _TTL}).encode())
    sig     = _b64(hmac.new(_SECRET.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"

def decode_token(token: str):
    try:
        header, payload, sig = token.split(".")
        expected = _b64(hmac.new(_SECRET.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected):
            return None
        data = json.loads(_unb64(payload))
        return None if data.get("exp", 0) < int(time.time()) else data
    except Exception:
        return None

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Token requerido"}), 401
        payload = decode_token(auth_header[7:])
        if not payload:
            return jsonify({"error": "Token inválido o expirado"}), 401

        from server.db import database as db
        rows = db.execute("SELECT * FROM users WHERE user_id = ?", (payload["sub"],)).fetchall()
        if not rows:
            return jsonify({"error": "Usuario no encontrado"}), 401
        g.user = dict(rows[0])
        return f(*args, **kwargs)
    return decorated
