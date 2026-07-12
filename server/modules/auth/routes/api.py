"""
server/modules/auth/routes/api.py
Endpoints del Servidor (Nube):
Auth, Usuarios, Hubs, Espacios (Spaces), Dispositivos y Notificaciones.
"""
import uuid
import hashlib
import os
import datetime
from flask import Blueprint, jsonify, request, g

from server.db import database as db
from server.modules.auth.middleware import generate_token, require_auth

auth_bp = Blueprint("server_auth_api", __name__)

def _hash_pw(password: str) -> str:
    salt = os.urandom(16).hex()
    h = hashlib.sha256((salt + password).encode()).hexdigest()
    return f"{salt}:{h}"

def _verify_pw(password: str, stored: str) -> bool:
    try:
        salt, h = stored.split(":", 1)
        return hashlib.sha256((salt + password).encode()).hexdigest() == h
    except Exception:
        return False

def _now():
    return datetime.datetime.now().isoformat()

def _generate_secret():
    return os.urandom(24).hex()


# ── Ping (sin auth) ─────────────────────────────────────────────
@auth_bp.route("/ping", methods=["GET"])
def api_ping():
    return jsonify({"ok": True, "service": "colmena-server"}), 200


# ── Signup & Login ──────────────────────────────────────────────
@auth_bp.route("/auth/signup", methods=["POST"])
def api_signup():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    email    = (data.get("email") or "").strip().lower()
    password = (data.get("password") or "").strip()

    if not username or not email or not password:
        return jsonify({"error": "Faltan datos"}), 400
    if len(password) < 6:
        return jsonify({"error": "Contraseña muy corta"}), 400

    if db.execute("SELECT user_id FROM users WHERE email = ?", (email,)).fetchone():
        return jsonify({"error": "Correo en uso"}), 409

    user_id = str(uuid.uuid4())
    db.execute(
        "INSERT INTO users (user_id, username, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
        (user_id, username, email, _hash_pw(password), _now())
    )
    return jsonify({
        "ok": True,
        "token": generate_token(user_id),
        "user": {"user_id": user_id, "username": username, "email": email},
    }), 201


@auth_bp.route("/auth/login", methods=["POST"])
def api_login():
    data = request.get_json(silent=True) or {}
    # Aceptar 'email', 'username' o 'identifier' como campo de búsqueda
    identifier = (data.get("email") or data.get("username") or data.get("identifier") or "").strip()
    password   = (data.get("password") or "").strip()

    if not identifier or not password:
        return jsonify({"error": "Faltan credenciales"}), 400

    # Buscar por email O username
    row = db.execute(
        "SELECT * FROM users WHERE email = ? OR username = ?",
        (identifier.lower(), identifier)
    ).fetchone()

    if not row or not _verify_pw(password, row["password_hash"]):
        return jsonify({"error": "Credenciales inválidas"}), 401

    user = dict(row)
    return jsonify({
        "ok": True,
        "token": generate_token(user["user_id"]),
        "user": {"user_id": user["user_id"], "username": user["username"], "email": user["email"]},
    }), 200


@auth_bp.route("/auth/me", methods=["GET"])
@require_auth
def api_me():
    u = g.user
    return jsonify({"ok": True, "user": {
        "user_id": u["user_id"], "username": u["username"], "email": u["email"]
    }}), 200


@auth_bp.route("/auth/logout", methods=["POST"])
@require_auth
def api_logout():
    return jsonify({"ok": True}), 200


# ── Hubs ────────────────────────────────────────────────────────
@auth_bp.route("/hubs", methods=["GET"])
@require_auth
def api_get_hubs():
    """Lista todos los hubs del usuario"""
    rows = db.execute("SELECT * FROM hubs WHERE user_id = ? ORDER BY created_at ASC", (g.user["user_id"],)).fetchall()
    return jsonify([dict(r) for r in rows]), 200

@auth_bp.route("/hubs", methods=["POST"])
@require_auth
def api_register_hub():
    """Registra un nuevo Hub. Es llamado por el Hub usando el token JWT del usuario."""
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "Nuevo Hub").strip()
    local_url = data.get("local_url", "")
    
    hub_id = str(uuid.uuid4())
    relay_secret = _generate_secret()
    
    db.execute(
        "INSERT INTO hubs (hub_id, user_id, name, local_url, relay_secret, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (hub_id, g.user["user_id"], name, local_url, relay_secret, _now())
    )
    
    return jsonify({
        "ok": True,
        "hub_id": hub_id,
        "relay_secret": relay_secret,
        "name": name,
        "local_url": local_url
    }), 201

@auth_bp.route("/hubs/<hub_id>", methods=["DELETE"])
@require_auth
def api_delete_hub(hub_id):
    row = db.execute("SELECT * FROM hubs WHERE hub_id = ?", (hub_id,)).fetchone()
    if not row or row["user_id"] != g.user["user_id"]:
        return jsonify({"error": "Hub no encontrado"}), 404
    db.execute("DELETE FROM devices WHERE hub_id = ?", (hub_id,))
    db.execute("DELETE FROM spaces WHERE hub_id = ?", (hub_id,))
    db.execute("DELETE FROM hubs WHERE hub_id = ?", (hub_id,))
    return jsonify({"ok": True}), 200

@auth_bp.route("/hubs/<hub_id>", methods=["PUT"])
@require_auth
def api_update_hub(hub_id):
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()
    if name:
        db.execute("UPDATE hubs SET name = ? WHERE hub_id = ? AND user_id = ?", (name, hub_id, g.user["user_id"]))
    return jsonify({"ok": True}), 200


# ── Espacios (Spaces) ────────────────────────────────────────────
@auth_bp.route("/hubs/<hub_id>/spaces", methods=["GET"])
@require_auth
def api_get_spaces(hub_id):
    rows = db.execute(
        "SELECT s.* FROM spaces s JOIN hubs h ON s.hub_id = h.hub_id WHERE s.hub_id = ? AND h.user_id = ?",
        (hub_id, g.user["user_id"])
    ).fetchall()
    return jsonify([dict(r) for r in rows]), 200

@auth_bp.route("/hubs/<hub_id>/spaces", methods=["POST"])
@require_auth
def api_create_space(hub_id):
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    icon = data.get("icon", "home")
    if not name:
        return jsonify({"error": "name requerido"}), 400
    
    # Verificar que el hub le pertenezca
    hub = db.execute("SELECT * FROM hubs WHERE hub_id = ? AND user_id = ?", (hub_id, g.user["user_id"])).fetchone()
    if not hub:
        return jsonify({"error": "Hub no encontrado"}), 404

    space_id = str(uuid.uuid4())
    db.execute(
        "INSERT INTO spaces (space_id, hub_id, name, icon, created_at) VALUES (?, ?, ?, ?, ?)",
        (space_id, hub_id, name, icon, _now())
    )
    return jsonify({"space_id": space_id, "hub_id": hub_id, "name": name, "icon": icon}), 201

@auth_bp.route("/hubs/<hub_id>/spaces/<space_id>", methods=["DELETE"])
@require_auth
def api_delete_space(hub_id, space_id):
    db.execute("UPDATE devices SET space_id = NULL WHERE space_id = ?", (space_id,))
    db.execute(
        "DELETE FROM spaces WHERE space_id = ? AND hub_id IN (SELECT hub_id FROM hubs WHERE user_id = ?)",
        (space_id, g.user["user_id"])
    )
    return jsonify({"ok": True}), 200


# ── Dispositivos ──────────────────────────────────────────────────
@auth_bp.route("/hubs/<hub_id>/devices", methods=["GET"])
@require_auth
def api_get_hub_devices(hub_id):
    rows = db.execute(
        "SELECT d.* FROM devices d JOIN hubs h ON d.hub_id = h.hub_id WHERE d.hub_id = ? AND h.user_id = ?",
        (hub_id, g.user["user_id"])
    ).fetchall()
    return jsonify([dict(r) for r in rows]), 200

@auth_bp.route("/hubs/<hub_id>/devices/<device_id>", methods=["POST", "PUT"])
@require_auth
def api_upsert_device(hub_id, device_id):
    """Guarda o actualiza un dispositivo en el servidor"""
    data = request.get_json(silent=True) or {}
    space_id = data.get("space_id")
    alias = data.get("alias", "")
    
    # Verificar owner
    hub = db.execute("SELECT * FROM hubs WHERE hub_id = ? AND user_id = ?", (hub_id, g.user["user_id"])).fetchone()
    if not hub:
        return jsonify({"error": "Hub no encontrado"}), 404
        
    db.execute(
        "INSERT OR REPLACE INTO devices (device_id, hub_id, space_id, alias, created_at) VALUES (?, ?, ?, ?, ?)",
        (device_id, hub_id, space_id, alias, _now())
    )
    return jsonify({"ok": True}), 200

@auth_bp.route("/hubs/<hub_id>/devices/<device_id>", methods=["DELETE"])
@require_auth
def api_delete_device(hub_id, device_id):
    db.execute(
        "DELETE FROM devices WHERE device_id = ? AND hub_id IN (SELECT hub_id FROM hubs WHERE user_id = ?)",
        (device_id, g.user["user_id"])
    )
    return jsonify({"ok": True}), 200


# ── Notificaciones ────────────────────────────────────────────────
@auth_bp.route("/user/notifications", methods=["GET"])
@require_auth
def api_get_notifications():
    limit = int(request.args.get("limit", 50))
    rows = db.execute(
        "SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ?",
        (g.user["user_id"], limit)
    ).fetchall()
    return jsonify([dict(r) for r in rows]), 200

@auth_bp.route("/user/notifications", methods=["POST"])
@require_auth
def api_create_notification():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title requerido"}), 400
    db.execute(
        "INSERT INTO notifications (user_id, hub_id, device_id, title, body, event_type, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (g.user["user_id"], data.get("hub_id", ""), data.get("device_id", ""), title,
         data.get("body", ""), data.get("event_type", "info"), _now())
    )
    return jsonify({"ok": True}), 201

@auth_bp.route("/user/notifications/<int:notif_id>/read", methods=["PUT"])
@require_auth
def api_mark_read(notif_id):
    db.execute("UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?", (notif_id, g.user["user_id"]))
    return jsonify({"ok": True}), 200


@auth_bp.route("/user/notifications/read-all", methods=["PUT"])
@require_auth
def api_mark_all_read():
    db.execute("UPDATE notifications SET read = 1 WHERE user_id = ?", (g.user["user_id"],))
    return jsonify({"ok": True}), 200


# ── FCM Token ─────────────────────────────────────────────────
@auth_bp.route("/auth/fcm-token", methods=["POST"])
@require_auth
def api_register_fcm_token():
    """
    Guarda o actualiza el token FCM del dispositivo del usuario autenticado.
    La app Flutter llama a este endpoint tras obtener el token de Firebase Messaging.
    Body: { "fcm_token": "<token>" }
    """
    data = request.get_json(silent=True) or {}
    token = (data.get("fcm_token") or data.get("token") or "").strip()
    if not token:
        return jsonify({"error": "fcm_token requerido"}), 400

    db.execute(
        "UPDATE users SET fcm_token = ? WHERE user_id = ?",
        (token, g.user["user_id"])
    )
    print(f"[FCM] Token registrado para usuario '{g.user['username']}': {token[:20]}...")
    return jsonify({"ok": True}), 200
