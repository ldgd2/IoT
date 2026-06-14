"""
IoT RF Gateway Server
Backend ultra-liviano para Raspberry Pi / hardware de bajos recursos
Comunicación por radiofrecuencia (RF433/nRF24/LoRa)
"""

from flask import Flask, render_template, jsonify, request
from datetime import datetime
import threading
import time
import json
import os

app = Flask(__name__)

# ─────────────────────────────────────────────
#  Estado en memoria (sin base de datos pesada)
# ─────────────────────────────────────────────
devices = {}       # { device_id: DeviceState }
rf_log   = []      # últimos N mensajes RF recibidos
MAX_LOG  = 200     # mantener memoria baja


class DeviceState:
    def __init__(self, device_id: str, name: str, device_type: str = "generic"):
        self.device_id   = device_id
        self.name        = name
        self.device_type = device_type          # light | sensor | relay | generic
        self.status      = "offline"            # online | offline | error
        self.state       = {}                   # payload libre del dispositivo
        self.last_seen   = None
        self.rssi        = None
        self.msg_count   = 0

    def update(self, payload: dict, rssi: int = None):
        self.state      = payload
        self.last_seen  = datetime.now().isoformat()
        self.status     = "online"
        self.rssi       = rssi
        self.msg_count += 1

    def to_dict(self):
        return {
            "id":          self.device_id,
            "name":        self.name,
            "type":        self.device_type,
            "status":      self.status,
            "state":       self.state,
            "last_seen":   self.last_seen,
            "rssi":        self.rssi,
            "msg_count":   self.msg_count,
        }


# ─────────────────────────────────────────────
#  Dispositivos de demo
# ─────────────────────────────────────────────
def seed_demo_devices():
    demos = [
        ("dev_001", "Luz Sala",       "light",   {"on": True,  "brightness": 80}),
        ("dev_002", "Luz Cocina",     "light",   {"on": False, "brightness": 60}),
        ("dev_003", "Sensor Temp",    "sensor",  {"temp": 23.4, "humidity": 55}),
        ("dev_004", "Relay Garage",   "relay",   {"on": False}),
        ("dev_005", "Sensor Humo",    "sensor",  {"smoke": False, "battery": 87}),
    ]
    for did, name, dtype, state in demos:
        d = DeviceState(did, name, dtype)
        d.update(state, rssi=-65)
        devices[did] = d


seed_demo_devices()


# ─────────────────────────────────────────────
#  Rutas HTML
# ─────────────────────────────────────────────
@app.route("/")
def dashboard():
    return render_template("dashboard.html", devices=list(devices.values()))


@app.route("/device/<device_id>")
def device_detail(device_id):
    dev = devices.get(device_id)
    if not dev:
        return "Device not found", 404
    return render_template("device.html", device=dev)


@app.route("/log")
def log_view():
    return render_template("log.html", log=list(reversed(rf_log[-100:])))


# ─────────────────────────────────────────────
#  API JSON  (para AJAX y dispositivos RF)
# ─────────────────────────────────────────────
@app.route("/api/devices", methods=["GET"])
def api_devices():
    return jsonify([d.to_dict() for d in devices.values()])


@app.route("/api/device/<device_id>", methods=["GET"])
def api_device(device_id):
    dev = devices.get(device_id)
    if not dev:
        return jsonify({"error": "not found"}), 404
    return jsonify(dev.to_dict())


@app.route("/api/ingest", methods=["POST"])
def api_ingest():
    """
    Endpoint que recibe datos del módulo RF gateway (Arduino/ESP/RPi).
    Payload esperado:
      { "id": "dev_001", "rssi": -72, "payload": { ... } }
    """
    data = request.get_json(silent=True)
    if not data or "id" not in data:
        return jsonify({"error": "bad request"}), 400

    device_id = data["id"]
    rssi      = data.get("rssi")
    payload   = data.get("payload", {})

    if device_id not in devices:
        devices[device_id] = DeviceState(
            device_id,
            data.get("name", f"Device {device_id}"),
            data.get("type", "generic"),
        )

    devices[device_id].update(payload, rssi)

    # Registrar en log
    rf_log.append({
        "ts":        datetime.now().isoformat(),
        "device_id": device_id,
        "rssi":      rssi,
        "payload":   payload,
    })
    if len(rf_log) > MAX_LOG:
        rf_log.pop(0)

    return jsonify({"ok": True})


@app.route("/api/command", methods=["POST"])
def api_command():
    """
    Envía un comando a un dispositivo vía RF (stub — conectar con driver RF real).
    { "id": "dev_001", "cmd": "set", "params": {"on": true} }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "bad request"}), 400

    device_id = data.get("id")
    dev = devices.get(device_id)
    if not dev:
        return jsonify({"error": "device not found"}), 404

    cmd    = data.get("cmd", "set")
    params = data.get("params", {})

    # Aplicar localmente (demo); en producción → enviar por RF
    dev.state.update(params)

    rf_log.append({
        "ts":        datetime.now().isoformat(),
        "device_id": device_id,
        "direction": "TX",
        "cmd":       cmd,
        "params":    params,
    })

    return jsonify({"ok": True, "state": dev.state})


@app.route("/api/stats", methods=["GET"])
def api_stats():
    online  = sum(1 for d in devices.values() if d.status == "online")
    offline = len(devices) - online
    return jsonify({
        "total":   len(devices),
        "online":  online,
        "offline": offline,
        "log_len": len(rf_log),
    })


# ─────────────────────────────────────────────
#  Watchdog: marca offline dispositivos sin señal
# ─────────────────────────────────────────────
OFFLINE_TIMEOUT = 60   # segundos


def watchdog():
    while True:
        now = datetime.now()
        for dev in devices.values():
            if dev.last_seen:
                dt = (now - datetime.fromisoformat(dev.last_seen)).total_seconds()
                if dt > OFFLINE_TIMEOUT:
                    dev.status = "offline"
        time.sleep(10)


threading.Thread(target=watchdog, daemon=True).start()


if __name__ == "__main__":
    # host="0.0.0.0" para acceder desde la red local
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
