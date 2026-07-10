#!/usr/bin/env python3
# =============================================================
# server/main.py
# Bridge Server (Teléfono <-> Hub) con Soporte de Red Protegida (Outbound Relay)
# =============================================================
import sys
import io
import os
import time
import uuid
import threading
from flask import Flask, request, jsonify
import requests

from config import SERVER_HOST, SERVER_PORT, HUB_URL, HUB_TIMEOUT

# Base de datos y auth del servidor
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).parent.parent.resolve()))
from server.db.database import ensure_tables
from server.modules.auth.routes.api import auth_bp

# Asegurar codificación UTF-8 en consola de Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

app = Flask(__name__)

try:
    from flask_cors import CORS
    CORS(app)
except ImportError:
    pass

# Registrar endpoints de Auth, Usuarios, Salas y Notificaciones
app.register_blueprint(auth_bp, url_prefix="/api")

# Crear tablas en la BD del servidor al arrancar
ensure_tables()

# Modo de operación: 'direct' (petición HTTP al Hub) o 'relay' (cola saliente para redes protegidas/NAT)
SERVER_MODE = os.environ.get("SERVER_MODE", "auto") # 'auto', 'direct', 'relay'
current_hub_url = HUB_URL

# Almacén en memoria para peticiones en Modo Relay (cuando el Hub está detrás de NAT/Firewall)
# Ahora soporta múltiples Hubs
pending_commands = {} # { hub_id: { cmd_id: { "data": dict, "timestamp": float } } }
completed_responses = {} # { cmd_id: dict }
cached_devices = {}      # { hub_id: [ devices... ] }
condition_lock = threading.Condition()


def require_hub_auth(f):
    """Verifica que el Hub envíe X-Hub-Id y X-Hub-Secret correctos para hacer polling"""
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        hub_id = request.headers.get("X-Hub-Id", "")
        secret = request.headers.get("X-Hub-Secret", "")
        if not hub_id or not secret:
            return jsonify({"error": "Faltan credenciales del Hub"}), 401
        
        from server.db import database as db
        row = db.execute("SELECT * FROM hubs WHERE hub_id = ? AND relay_secret = ?", (hub_id, secret)).fetchone()
        if not row:
            return jsonify({"error": "Credenciales inválidas"}), 401
        
        # Actualizar last_seen
        from datetime import datetime
        db.execute("UPDATE hubs SET last_seen = ?, online = 1 WHERE hub_id = ?", (datetime.now().isoformat(), hub_id))
        
        request.hub_record = dict(row)
        return f(*args, **kwargs)
    return decorated


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "service": "Colmena Cloud Server (Multi-Hub)",
        "status": "online",
        "mode": SERVER_MODE,
        "message": "Servidor activo con arquitectura Multi-Hub."
    })


@app.route("/api/health", methods=["GET"])
@app.route("/api/stats", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "server": "online",
        "server_mode": SERVER_MODE
    })


# =============================================================
# RUTAS PARA EL AGENTE DEL HUB (OUTBOUND POLLING MULTI-HUB)
# =============================================================

@app.route("/api/hub/poll", methods=["GET"])
@require_hub_auth
def hub_poll():
    hub_id = request.hub_record["hub_id"]
    
    with condition_lock:
        if hub_id not in pending_commands:
            pending_commands[hub_id] = {}
            
        # Si no hay comandos pendientes para este hub, esperar (Long-Polling)
        if not pending_commands[hub_id]:
            condition_lock.wait(timeout=3.0)
            
        if pending_commands[hub_id]:
            # Obtener el primer comando pendiente
            cmd_id, job = next(iter(pending_commands[hub_id].items()))
            return jsonify({"status": "job", "cmd_id": cmd_id, "payload": job["data"]}), 200
            
    return jsonify({"status": "empty"}), 200


@app.route("/api/hub/response", methods=["POST"])
@require_hub_auth
def hub_response():
    hub_id = request.hub_record["hub_id"]
    data = request.get_json(silent=True) or {}
    cmd_id = data.get("cmd_id")
    result = data.get("result", {})
    
    if cmd_id and hub_id in pending_commands and cmd_id in pending_commands[hub_id]:
        with condition_lock:
            del pending_commands[hub_id][cmd_id]
            completed_responses[cmd_id] = result
            condition_lock.notify_all()
        return jsonify({"status": "ok"}), 200
        
    return jsonify({"status": "error", "message": "Trabajo no encontrado"}), 404


@app.route("/api/hub/sync", methods=["POST"])
@require_hub_auth
def hub_sync():
    hub_id = request.hub_record["hub_id"]
    data = request.get_json(silent=True) or {}
    devs = data.get("devices")
    if isinstance(devs, list):
        _detect_and_notify_offline(hub_id, devs)
        cached_devices[hub_id] = devs
        return jsonify({"status": "ok"}), 200
    return jsonify({"status": "error"}), 400


def _detect_and_notify_offline(hub_id: str, new_devices: list):
    """
    Compara el nuevo listado de dispositivos del Hub con el caché anterior.
    Si algún dispositivo que estaba 'online' ahora está 'offline' (o desapareció),
    dispara una notificación push al propietario del Hub.
    """
    try:
        from server.modules.notifications.fcm import notify_device_offline

        prev = cached_devices.get(hub_id, [])
        # Construir mapas { device_id -> status } de la sincronización anterior
        prev_status = {d.get("device_id", d.get("id", "")): d.get("status", "offline") for d in prev}
        new_status  = {d.get("device_id", d.get("id", "")): d for d in new_devices}

        for dev_id, old_st in prev_status.items():
            new_dev = new_status.get(dev_id)
            # Caso 1: dispositivo presente pero ahora offline
            if new_dev is not None:
                current_st = new_dev.get("status", "offline")
                if old_st == "online" and current_st != "online":
                    dev_name = new_dev.get("name", dev_id)
                    print(f"📴 [SYNC] Dispositivo '{dev_name}' ({dev_id}) pasó a OFFLINE en Hub {hub_id}")
                    import threading
                    threading.Thread(
                        target=notify_device_offline,
                        args=(hub_id, dev_name, dev_id),
                        daemon=True
                    ).start()
            # Caso 2: dispositivo desapareció del listado y antes estaba online
            elif old_st == "online":
                dev_name = dev_id  # sin info de nombre, usar ID
                print(f"📴 [SYNC] Dispositivo '{dev_name}' desapareció del Hub {hub_id} (se asume offline)")
                import threading
                threading.Thread(
                    target=notify_device_offline,
                    args=(hub_id, dev_name, dev_id),
                    daemon=True
                ).start()
    except Exception as e:
        print(f"⚠️ [SYNC] Error al detectar dispositivos offline: {e}")


# =============================================================
# RUTAS PARA EL TELÉFONO MÓVIL (APP)
# =============================================================
from server.modules.auth.middleware import require_auth

@app.route("/api/hubs/<hub_id>/command", methods=["POST"])
@require_auth
def relay_command(hub_id):
    """
    Ruta de comando del teléfono, dirigida a un Hub específico.
    Utiliza el Modo Relay (Outbound Polling) hacia el Hub objetivo.
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Payload JSON vacío"}), 400

    from server.db import database as db
    # Validar que el hub pertenece al usuario
    hub = db.execute("SELECT * FROM hubs WHERE hub_id = ? AND user_id = ?", (hub_id, request.environ.get('flask.g').user["user_id"])).fetchone()
    if not hub:
        return jsonify({"error": "Hub no encontrado o no pertenece al usuario"}), 404

    cmd_id = str(uuid.uuid4())[:8]
    
    with condition_lock:
        if hub_id not in pending_commands:
            pending_commands[hub_id] = {}
        pending_commands[hub_id][cmd_id] = {"data": data, "timestamp": time.time()}
        condition_lock.notify_all()
        
        # Esperar hasta 6 segundos a que el Hub recoja y responda
        start_wait = time.time()
        while cmd_id not in completed_responses:
            elapsed = time.time() - start_wait
            if elapsed >= 6.0:
                if cmd_id in pending_commands.get(hub_id, {}):
                    del pending_commands[hub_id][cmd_id]
                return jsonify({"error": "El Hub no respondió a tiempo. Verifica que esté encendido y conectado a internet."}), 504
            condition_lock.wait(timeout=1.0)
            
        res = completed_responses.pop(cmd_id)
        return jsonify({
            "ok": True,
            "message": "Comando ejecutado vía relay",
            "hub_response": res,
            "state": res.get("state", data.get("params", {}))
        }), 200


def _generic_proxy(hub_id, path, method="GET", json_data=None):
    """Reenvío directo al hub usando su local_url (Solo si app y hub están en misma LAN)"""
    from server.db import database as db
    hub = db.execute("SELECT local_url FROM hubs WHERE hub_id = ?", (hub_id,)).fetchone()
    if not hub or not hub["local_url"]:
        return jsonify({"error": "Hub sin URL local configurada"}), 404
        
    url = f"{hub['local_url']}/{path.lstrip('/')}"
    try:
        if method == "GET":
            r = requests.get(url, timeout=4)
        elif method == "POST":
            r = requests.post(url, json=json_data, headers={"Content-Type": "application/json"}, timeout=4)
        elif method == "DELETE":
            r = requests.delete(url, timeout=4)
        else:
            r = requests.request(method, url, json=json_data, timeout=4)
        return (r.content, r.status_code, r.headers.items())
    except Exception as e:
        return jsonify({"error": f"Fallo directo a {url}: {e}"}), 502


def _get_target_hub_id(explicit_hub_id=None):
    if explicit_hub_id:
        return explicit_hub_id
    header_hub = request.headers.get("X-Hub-Id")
    if header_hub:
        return header_hub
    try:
        from server.db import database as db
        from flask import g
        user = getattr(g, "user", None)
        if user and "user_id" in user:
            hub = db.execute("SELECT hub_id FROM hubs WHERE user_id = ?", (user["user_id"],)).fetchone()
            if hub:
                return hub["hub_id"]
    except Exception:
        pass
    if cached_devices:
        return list(cached_devices.keys())[0]
    return None


def _execute_relay_job(hub_id: str, payload: dict, timeout=6.0):
    if not hub_id:
        return {"error": "Hub ID no identificado ni proporcionado"}, 400
    cmd_id = str(uuid.uuid4())[:8]
    with condition_lock:
        if hub_id not in pending_commands:
            pending_commands[hub_id] = {}
        pending_commands[hub_id][cmd_id] = {"data": payload, "timestamp": time.time()}
        condition_lock.notify_all()
        
        start_wait = time.time()
        while cmd_id not in completed_responses:
            elapsed = time.time() - start_wait
            if elapsed >= timeout:
                if cmd_id in pending_commands.get(hub_id, {}):
                    del pending_commands[hub_id][cmd_id]
                return {"error": "El Hub no respondió a tiempo al comando remota."}, 504
            condition_lock.wait(timeout=1.0)
            
        res = completed_responses.pop(cmd_id)
        return res, 200


@app.route("/api/command", methods=["POST"])
@require_auth
def relay_api_command():
    target_hub = _get_target_hub_id()
    if not target_hub:
        return jsonify({"error": "Hub no encontrado"}), 404
    return relay_command(target_hub)


@app.route("/api/pairing", methods=["POST"])
@app.route("/api/hubs/<hub_id>/pairing", methods=["POST"])
@require_auth
def relay_api_pairing(hub_id=None):
    target_hub = _get_target_hub_id(hub_id)
    data = request.get_json(silent=True) or {}
    action = data.get("action", "start")
    res, status = _execute_relay_job(target_hub, {"cmd": "pairing", "action": action})
    return jsonify(res), status


@app.route("/api/pairing/status", methods=["GET"])
@app.route("/api/hubs/<hub_id>/pairing/status", methods=["GET"])
@require_auth
def relay_api_pairing_status(hub_id=None):
    target_hub = _get_target_hub_id(hub_id)
    res, status = _execute_relay_job(target_hub, {"cmd": "pairing_status"}, timeout=3.5)
    return jsonify(res), status


@app.route("/api/devices", methods=["GET"])
@app.route("/api/hubs/<hub_id>/devices_sync", methods=["GET"])
@require_auth
def relay_api_get_devices(hub_id=None):
    target_hub = _get_target_hub_id(hub_id)
    if target_hub and target_hub in cached_devices and len(cached_devices[target_hub]) > 0:
        return jsonify(cached_devices[target_hub]), 200
    res, status = _execute_relay_job(target_hub, {"cmd": "sync_devices"}, timeout=4.5)
    if status == 200 and isinstance(res, dict) and "devices" in res:
        cached_devices[target_hub] = res["devices"]
        return jsonify(res["devices"]), 200
    return jsonify(cached_devices.get(target_hub, [])), 200


@app.route("/api/devices", methods=["POST"])
@require_auth
def relay_api_register_device():
    target_hub = _get_target_hub_id()
    data = request.get_json(silent=True) or {}
    payload = {"cmd": "register_device"}
    payload.update(data)
    res, status = _execute_relay_job(target_hub, payload, timeout=5.0)
    cached_devices.pop(target_hub, None)
    return jsonify(res), status


@app.route("/api/device/<device_id>", methods=["PUT", "POST", "PATCH"])
@app.route("/api/devices/<device_id>", methods=["PUT", "POST", "PATCH"])
@require_auth
def relay_api_update_device(device_id):
    target_hub = _get_target_hub_id()
    data = request.get_json(silent=True) or {}
    payload = {"cmd": "update_device", "device_id": device_id}
    payload.update(data)
    res, status = _execute_relay_job(target_hub, payload, timeout=5.0)
    cached_devices.pop(target_hub, None)
    return jsonify(res), status


@app.route("/api/device/<device_id>", methods=["DELETE"])
@app.route("/api/devices/<device_id>", methods=["DELETE"])
@require_auth
def relay_api_delete_device(device_id):
    target_hub = _get_target_hub_id()
    payload = {"cmd": "delete_device", "device_id": device_id}
    res, status = _execute_relay_job(target_hub, payload, timeout=5.0)
    cached_devices.pop(target_hub, None)
    return jsonify(res), status


if __name__ == "__main__":
    print("\n" + "*"*65)
    print("🚀 IoT Bridge Server (Multi-Hub Architecture)")
    print(f"🌐 Escuchando en: http://{SERVER_HOST}:{SERVER_PORT}")
    print("*"*65 + "\n")
    app.run(host=SERVER_HOST, port=SERVER_PORT, debug=False, threaded=True)

