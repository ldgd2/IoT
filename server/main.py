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

# Asegurar codificación UTF-8 en consola de Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

app = Flask(__name__)

try:
    from flask_cors import CORS
    CORS(app)
except ImportError:
    pass

# Modo de operación: 'direct' (petición HTTP al Hub) o 'relay' (cola saliente para redes protegidas/NAT)
SERVER_MODE = os.environ.get("SERVER_MODE", "auto") # 'auto', 'direct', 'relay'
current_hub_url = HUB_URL

# Almacén en memoria para peticiones en Modo Relay (cuando la red del Hub está detrás de NAT/Firewall)
pending_commands = {} # { cmd_id: { "data": dict, "timestamp": float } }
completed_responses = {} # { cmd_id: dict }
cached_devices = []      # Lista sincronizada por el Hub para redes protegidas
condition_lock = threading.Condition()


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "service": "IoT Bridge Server (Phone <-> Hub)",
        "status": "online",
        "mode": SERVER_MODE,
        "target_hub": current_hub_url,
        "pending_relay_jobs": len(pending_commands),
        "message": "Servidor activo. Soporta conexión directa y Modo Relay para redes protegidas sin IP saliente."
    })


@app.route("/api/health", methods=["GET"])
@app.route("/api/stats", methods=["GET"])
def health_check():
    """Verifica el estado del servidor y del Hub"""
    hub_online = False
    hub_info = {}
    
    # Intento directo de consulta al Hub
    try:
        r = requests.get(f"{current_hub_url}/api/stats", timeout=2)
        if r.status_code == 200:
            hub_online = True
            hub_info = r.json()
    except Exception as e:
        hub_info = {"status": "relay_mode_active", "note": "El Hub está detrás de firewall/NAT conectándose vía Polling Outbound."}

    return jsonify({
        "status": "ok",
        "server": "online",
        "server_mode": SERVER_MODE,
        "hub_connected": hub_online or len(completed_responses) > 0,
        "hub_url": current_hub_url,
        "hub_data": hub_info
    })


@app.route("/api/config/mode", methods=["POST"])
def configure_mode():
    """Configura el modo: 'direct' o 'relay'"""
    global SERVER_MODE
    data = request.get_json(silent=True) or {}
    mode = data.get("mode", "auto")
    SERVER_MODE = mode
    print(f"⚙️ [CONFIG] Modo de servidor cambiado a: {SERVER_MODE}")
    return jsonify({"status": "ok", "mode": SERVER_MODE})


# =============================================================
# RUTAS PARA EL AGENTE DEL HUB EN RED PROTEGIDA (OUTBOUND POLLING)
# =============================================================

@app.route("/api/hub/poll", methods=["GET"])
def hub_poll():
    """
    El Gateway Hub (o hub_agent.py) dentro de la red protegida llama a esta ruta SALIENTE.
    Como la petición sale desde dentro hacia afuera, el firewall/NAT la permite sin problemas.
    """
    with condition_lock:
        # Si no hay comandos pendientes, esperar hasta 3 segundos por si entra uno (Long-Polling)
        if not pending_commands:
            condition_lock.wait(timeout=3.0)
            
        if pending_commands:
            # Obtener el primer comando pendiente
            cmd_id, job = next(iter(pending_commands.items()))
            # Retornar el comando para que el Hub lo ejecute localmente
            return jsonify({"status": "job", "cmd_id": cmd_id, "payload": job["data"]}), 200
            
    return jsonify({"status": "empty"}), 200


@app.route("/api/hub/response", methods=["POST"])
def hub_response():
    """El Gateway Hub devuelve aquí el resultado del comando ejecutado localmente."""
    data = request.get_json(silent=True) or {}
    cmd_id = data.get("cmd_id")
    result = data.get("result", {})
    
    if cmd_id and cmd_id in pending_commands:
        with condition_lock:
            del pending_commands[cmd_id]
            completed_responses[cmd_id] = result
            condition_lock.notify_all()
        print(f"📡 [HUB RELAY -> SERVER] Respuesta recibida para trabajo {cmd_id}: OK")
        return jsonify({"status": "ok"}), 200
        
    return jsonify({"status": "error", "message": "Trabajo no encontrado o ya expiró"}), 404


@app.route("/api/hub/sync", methods=["POST"])
def hub_sync():
    """El Gateway Hub sincroniza su catálogo de dispositivos aquí periódicamente."""
    global cached_devices
    data = request.get_json(silent=True) or {}
    devs = data.get("devices")
    if isinstance(devs, list):
        cached_devices = devs
        print(f"🔄 [HUB RELAY -> SERVER] Catálogo sincronizado: {len(cached_devices)} dispositivos.")
        return jsonify({"status": "ok"}), 200
    return jsonify({"status": "error"}), 400


# =============================================================
# RUTAS PARA EL TELÉFONO MÓVIL
# =============================================================

@app.route("/api/devices", methods=["GET"])
def get_devices():
    """Consulta dispositivos al Hub (o caché en Modo Relay)"""
    print(f"📱 [TELÉFONO -> SERVER] Consultando lista de dispositivos...")
    if SERVER_MODE == "relay":
        return jsonify(cached_devices), 200
    try:
        r = requests.get(f"{current_hub_url}/api/devices", timeout=3)
        return (r.content, r.status_code, r.headers.items())
    except Exception as e:
        print(f"⚠️ [NOTICE] Hub directo no accesible. Devolviendo caché ({len(cached_devices)} dispositivos).")
        return jsonify(cached_devices), 200


@app.route("/api/command", methods=["POST"])
def relay_command():
    """
    Ruta de comando del teléfono.
    Si la red no permite peticiones entrantes, utiliza el Modo Relay saliente.
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"status": "error", "message": "Payload JSON vacío"}), 400

    device_id = data.get("id")
    cmd = data.get("cmd")
    params = data.get("params", {})

    print(f"\n" + "="*55)
    print(f"📱 [TELÉFONO -> SERVER] Orden para dispositivo {device_id}: {cmd} | {params}")

    # 1. INTENTO DIRECTO (Si el servidor y el Hub están en red local o VPN)
    if SERVER_MODE in ["auto", "direct"]:
        try:
            print(f"   Intentando conexión directa al Hub ({current_hub_url})...")
            r = requests.post(
                f"{current_hub_url}/api/command",
                json=data,
                headers={"Content-Type": "application/json"},
                timeout=3
            )
            if r.status_code == 200:
                hub_res = r.json()
                print(f"📡 [HUB DIRECTO] Ejecutado con éxito.")
                print("="*55 + "\n")
                return jsonify({
                    "status": "ok",
                    "message": "Comando ejecutado vía conexión directa",
                    "hub_response": hub_res,
                    "state": hub_res.get("state", params)
                }), 200
        except Exception as e:
            if SERVER_MODE == "direct":
                return jsonify({"status": "error", "message": f"Fallo directo al Hub: {e}"}), 502
            print(f"   [NOTICE] Conexión directa falló. Pasando automáticamente a Modo Relay (Red Protegida)...")

    # 2. MODO RELAY / OUTBOUND POLLING (Para redes protegidas por NAT / Firewall)
    cmd_id = str(uuid.uuid4())[:8]
    print(f"🛡️ [MODO RELAY] Encolando trabajo {cmd_id} para que el Hub local lo consuma desde dentro...")
    
    with condition_lock:
        pending_commands[cmd_id] = {"data": data, "timestamp": time.time()}
        condition_lock.notify_all()
        
        # Esperar hasta 6 segundos a que el agente local del Hub recoja y responda la orden
        start_wait = time.time()
        while cmd_id not in completed_responses:
            elapsed = time.time() - start_wait
            if elapsed >= 6.0:
                del pending_commands[cmd_id]
                print(f"⏰ [TIMEOUT] El Hub en red local no recogió el comando en 6s.")
                print("="*55 + "\n")
                return jsonify({
                    "status": "error",
                    "message": "El Hub en la red protegida no consultó el servidor a tiempo. Verifica que hub_agent.py esté corriendo."
                }), 504
            condition_lock.wait(timeout=1.0)
            
        res = completed_responses.pop(cmd_id)
        print(f"📡 [HUB RELAY] ¡El Hub procesó la orden desde su red protegida!")
        print("="*55 + "\n")
        return jsonify({
            "status": "ok",
            "message": "Comando ejecutado con éxito a través de túnel saliente (Relay)",
            "hub_response": res,
            "state": res.get("state", params)
        }), 200


def _generic_proxy(path, method="GET", json_data=None):
    """Auxiliar para reenviar peticiones al Hub directamente o via relay"""
    url = f"{current_hub_url}/{path.lstrip('/')}"
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
        return jsonify({"error": f"Fallo al conectar con Hub en {url}: {e}"}), 502

@app.route("/api/devices", methods=["POST"])
def proxy_post_devices():
    return _generic_proxy("/api/devices", method="POST", json_data=request.get_json(silent=True) or {})

@app.route("/api/device/<device_id>", methods=["GET", "PUT", "POST", "PATCH", "DELETE"])
def proxy_device_detail(device_id):
    return _generic_proxy(f"/api/device/{device_id}", method=request.method, json_data=request.get_json(silent=True) or {})

@app.route("/api/pairing", methods=["POST"])
def proxy_pairing():
    return _generic_proxy("/api/pairing", method="POST", json_data=request.get_json(silent=True) or {})

@app.route("/api/pairing/status", methods=["GET"])
def proxy_pairing_status():
    return _generic_proxy("/api/pairing/status", method="GET")

@app.route("/api/device-token/", methods=["POST", "PUT"])
@app.route("/api/device-token", methods=["POST", "PUT"])
@app.route("/device-token/", methods=["POST", "PUT"])
@app.route("/device-token", methods=["POST", "PUT"])
def proxy_device_token():
    return _generic_proxy("/api/device-token", method="POST", json_data=request.get_json(silent=True) or {})

@app.route("/api/notifications", methods=["GET", "DELETE"])
def proxy_notifications():
    return _generic_proxy("/api/notifications", method=request.method)

@app.route("/api/notifications/test", methods=["POST"])
def proxy_notifications_test():
    return _generic_proxy("/api/notifications/test", method="POST", json_data=request.get_json(silent=True) or {})

@app.route("/api/skills", methods=["GET", "POST"])
def proxy_skills():
    return _generic_proxy("/api/skills", method=request.method, json_data=request.get_json(silent=True) or {})

@app.route("/api/skills/<int:skill_id>", methods=["GET", "DELETE"])
@app.route("/api/skills/<int:skill_id>/toggle", methods=["POST"])
@app.route("/api/skills/<int:skill_id>/execute", methods=["POST"])
def proxy_skills_detail(skill_id):
    path = request.path
    return _generic_proxy(path, method=request.method, json_data=request.get_json(silent=True) or {})

if __name__ == "__main__":
    print("\n" + "*"*65)
    print("🚀 IoT Bridge Server (Soporta Redes Protegidas sin IP Saliente)")
    print(f"🌐 Escuchando en: http://{SERVER_HOST}:{SERVER_PORT}")
    print("*"*65 + "\n")
    app.run(host=SERVER_HOST, port=SERVER_PORT, debug=False, threaded=True)
