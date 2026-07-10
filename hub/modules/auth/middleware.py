"""
hub/modules/auth/middleware.py
JWT muy liviano sin dependencias externas (usa hmac + base64).
Formato: base64(header).base64(payload).base64(signature)
"""
import base64
import hashlib
import hmac
import json
import os
import time
from functools import wraps
from flask import request, jsonify, g

from hub.modules.auth.models.user import User

# Clave secreta leída del entorno o fallback de desarrollo
_SECRET = os.getenv("JWT_SECRET", "colmena_jwt_super_secret_2026_change_me")
_TTL = int(os.getenv("JWT_TTL_SECONDS", 60 * 60 * 24 * 30))  # 30 días


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64(s: str) -> bytes:
    pad = 4 - len(s) % 4
    return base64.urlsafe_b64decode(s + "=" * (pad % 4))


def generate_token(user_id: str) -> str:
    header = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64(json.dumps({
        "sub": user_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + _TTL,
    }).encode())
    sig = _b64(hmac.new(
        _SECRET.encode(), f"{header}.{payload}".encode(), hashlib.sha256
    ).digest())
    return f"{header}.{payload}.{sig}"


def decode_token(token: str):
    """Retorna dict con el payload si el token es válido, None si no."""
    try:
        header, payload, sig = token.split(".")
        expected_sig = _b64(hmac.new(
            _SECRET.encode(), f"{header}.{payload}".encode(), hashlib.sha256
        ).digest())
        if not hmac.compare_digest(sig, expected_sig):
            return None
        data = json.loads(_unb64(payload))
        if data.get("exp", 0) < int(time.time()):
            return None
        return data
    except Exception:
        return None


def require_auth(f):
    """Decorador: protege un endpoint y pone g.user con el User autenticado."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Token requerido"}), 401
        token = auth_header[7:]
        payload = decode_token(token)
        if not payload:
            return jsonify({"error": "Token inválido o expirado"}), 401
        user = User.get_by_id(payload["sub"])
        if not user:
            return jsonify({"error": "Usuario no encontrado"}), 401
        g.user = user
        return f(*args, **kwargs)
    return decorated
