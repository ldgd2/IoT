"""
hub/modules/auth/routes/api.py
Endpoints de autenticación y gestión de usuario.
Rutas públicas:  POST /api/auth/signup, POST /api/auth/login
Rutas protegidas: GET /api/auth/me, POST /api/auth/logout
"""
from flask import Blueprint, jsonify, request, g

from hub.modules.auth.models.user import User
from hub.modules.auth.models.room import Room
from hub.modules.auth.middleware import generate_token, require_auth
from hub.modules.communication.models.notification import NotificationLog
from hub.db.database import Database

auth_bp = Blueprint("auth_api", __name__)


# ── Ping (sin auth, para validar conexión desde la app) ──────
@auth_bp.route("/ping", methods=["GET"])
def api_ping():
    return jsonify({"ok": True, "service": "colmena-hub"}), 200


# ── Registro ─────────────────────────────────────────────────
@auth_bp.route("/auth/signup", methods=["POST"])
def api_signup():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    email    = (data.get("email") or "").strip().lower()
    password = (data.get("password") or "").strip()

    if not username or not email or not password:
        return jsonify({"error": "username, email y password son requeridos"}), 400
    if len(password) < 6:
        return jsonify({"error": "La contraseña debe tener al menos 6 caracteres"}), 400

    existing = User.get_by_email(email)
    if existing:
        return jsonify({"error": "El correo ya está registrado"}), 409

    user = User.create(username=username, email=email, password=password)
    token = generate_token(user.user_id)
    return jsonify({
        "ok": True,
        "token": token,
        "user": user.to_dict(),
    }), 201


# ── Login ────────────────────────────────────────────────────
@auth_bp.route("/auth/login", methods=["POST"])
def api_login():
    data = request.get_json(silent=True) or {}
    email    = (data.get("email") or "").strip().lower()
    password = (data.get("password") or "").strip()

    if not email or not password:
        return jsonify({"error": "email y password requeridos"}), 400

    user = User.get_by_email(email)
    if not user or not user.verify_password(password):
        return jsonify({"error": "Correo o contraseña incorrectos"}), 401

    token = generate_token(user.user_id)
    return jsonify({
        "ok": True,
        "token": token,
        "user": user.to_dict(),
    }), 200


# ── Me ────────────────────────────────────────────────────────
@auth_bp.route("/auth/me", methods=["GET"])
@require_auth
def api_me():
    return jsonify({"ok": True, "user": g.user.to_dict()}), 200


# ── Logout (el token no se invalida del lado del servidor,
#           el cliente simplemente lo borra) ──────────────────
@auth_bp.route("/auth/logout", methods=["POST"])
@require_auth
def api_logout():
    return jsonify({"ok": True}), 200


# ── FCM Token (para push notifications vinculadas al usuario) ─
@auth_bp.route("/auth/fcm-token", methods=["PUT"])
@require_auth
def api_update_fcm():
    data = request.get_json(silent=True) or {}
    fcm_token = data.get("fcm_token", "")
    Database.execute(
        "UPDATE users SET fcm_token = ? WHERE user_id = ?",
        (fcm_token, g.user.user_id)
    )
    return jsonify({"ok": True}), 200


# ── Salas ────────────────────────────────────────────────────
@auth_bp.route("/rooms", methods=["GET"])
@require_auth
def api_get_rooms():
    rooms = Room.get_by_user(g.user.user_id)
    return jsonify([r.to_dict() for r in rooms]), 200


@auth_bp.route("/rooms", methods=["POST"])
@require_auth
def api_create_room():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    icon = data.get("icon", "home")
    if not name:
        return jsonify({"error": "name requerido"}), 400
    room = Room.create(user_id=g.user.user_id, name=name, icon=icon)
    return jsonify(room.to_dict()), 201


@auth_bp.route("/rooms/<room_id>", methods=["DELETE"])
@require_auth
def api_delete_room(room_id):
    room = Room.get_by_id(room_id)
    if not room or room.user_id != g.user.user_id:
        return jsonify({"error": "Sala no encontrada"}), 404
    Database.execute("DELETE FROM rooms WHERE room_id = ?", (room_id,))
    return jsonify({"ok": True}), 200


# ── Notificaciones del usuario ────────────────────────────────
@auth_bp.route("/user/notifications", methods=["GET"])
@require_auth
def api_user_notifications():
    limit = int(request.args.get("limit", 50))
    rows = Database.execute(
        "SELECT * FROM notification_logs ORDER BY ts DESC LIMIT ?", (limit,)
    ).fetchall()
    return jsonify([dict(r) for r in rows]), 200
