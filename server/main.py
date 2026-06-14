"""
IoT RF Gateway Server - main.py
Backend ultra-liviano para Raspberry Pi
Comunicación por radiofrecuencia (RF433/nRF24/LoRa)
"""
import sys
from pathlib import Path
# Agregar ruta raíz al path para importar modulos
sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))

from flask import Flask, render_template, jsonify, request
from datetime import datetime
import threading
import time
import json

from server.core.config import API_PORT
from server.db.database import BaseModel
from server.db.models import Device, RFLog

app = Flask(__name__)

# Aseguramos de que las tablas existan al inicio invocando al padre
BaseModel.migrate_all()

# ─────────────────────────────────────────────
#  Dispositivos de demo (Seed)
# ─────────────────────────────────────────────
def seed_demo_devices():
    if not Device.all():
        demos = [
            ("dev_001", "Luz Sala",       "light",   {"on": True,  "brightness": 80}),
            ("dev_002", "Luz Cocina",     "light",   {"on": False, "brightness": 60}),
            ("dev_003", "Sensor Temp",    "sensor",  {"temp": 23.4, "humidity": 55}),
            ("dev_004", "Relay Garage",   "relay",   {"on": False}),
            ("dev_005", "Sensor Humo",    "sensor",  {"smoke": False, "battery": 87}),
        ]
        for did, name, dtype, state in demos:
            d = Device(device_id=did, name=name, device_type=dtype)
            d.update(state, rssi=-65)

seed_demo_devices()


# ─────────────────────────────────────────────
#  Rutas HTML
# ─────────────────────────────────────────────
@app.route("/")
def dashboard():
    return render_template("dashboard.html", devices=Device.all())


@app.route("/device/<device_id>")
def device_detail(device_id):
    dev = Device.get(device_id)
    if not dev:
        return "Device not found", 404
    return render_template("device.html", device=dev)


@app.route("/log")
def log_view():
    from server.db.database import Database
    cursor = Database.execute("SELECT * FROM rf_logs ORDER BY id DESC LIMIT 100")
    logs = []
    for r in cursor.fetchall():
        d = dict(r)
        if isinstance(d.get("payload"), str):
            try: d["payload"] = json.loads(d["payload"])
            except: pass
        logs.append(d)
    return render_template("log.html", log=logs)


# ─────────────────────────────────────────────
#  API JSON  (para AJAX y dispositivos RF)
# ─────────────────────────────────────────────
@app.route("/api/devices", methods=["GET"])
def api_devices():
    return jsonify([d.to_dict() for d in Device.all()])


@app.route("/api/device/<device_id>", methods=["GET"])
def api_device(device_id):
    dev = Device.get(device_id)
    if not dev:
        return jsonify({"error": "not found"}), 404
    return jsonify(dev.to_dict())


@app.route("/api/ingest", methods=["POST"])
def api_ingest():
    data = request.get_json(silent=True)
    if not data or "id" not in data:
        return jsonify({"error": "bad request"}), 400

    device_id = data["id"]
    rssi      = data.get("rssi", 0)
    payload   = data.get("payload", {})

    dev = Device.get(device_id)
    if not dev:
        dev = Device(
            device_id=device_id,
            name=data.get("name", f"Device {device_id}"),
            device_type=data.get("type", "generic")
        )
    
    dev.update(payload, rssi)

    log = RFLog(
        ts=datetime.now().isoformat(),
        device_id=device_id,
        rssi=rssi,
        payload=payload,
        direction="RX"
    )
    log.save()

    return jsonify({"ok": True})


@app.route("/api/command", methods=["POST"])
def api_command():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "bad request"}), 400

    device_id = data.get("id")
    dev = Device.get(device_id)
    if not dev:
        return jsonify({"error": "device not found"}), 404

    cmd    = data.get("cmd", "set")
    params = data.get("params", {})

    if isinstance(dev.state, dict):
        dev.state.update(params)
    dev.save()

    log = RFLog(
        ts=datetime.now().isoformat(),
        device_id=device_id,
        direction="TX",
        cmd=cmd,
        payload=params
    )
    log.save()

    return jsonify({"ok": True, "state": dev.state})


@app.route("/api/stats", methods=["GET"])
def api_stats():
    devices = Device.all()
    online = sum(1 for d in devices if d.status == "online")
    from server.db.database import Database
    cursor = Database.execute("SELECT COUNT(*) as c FROM rf_logs")
    log_count = cursor.fetchone()["c"]
    
    return jsonify({
        "total":   len(devices),
        "online":  online,
        "offline": len(devices) - online,
        "log_len": log_count,
    })


# ─────────────────────────────────────────────
#  Watchdog: marca offline dispositivos sin señal
# ─────────────────────────────────────────────
OFFLINE_TIMEOUT = 60

def watchdog():
    while True:
        now = datetime.now()
        for dev in Device.all():
            if dev.last_seen:
                try:
                    dt = (now - datetime.fromisoformat(dev.last_seen)).total_seconds()
                    if dt > OFFLINE_TIMEOUT and dev.status != "offline":
                        dev.status = "offline"
                        dev.save()
                except ValueError:
                    pass
        time.sleep(10)

threading.Thread(target=watchdog, daemon=True).start()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=API_PORT, debug=False, threaded=True)
