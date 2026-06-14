from flask import Blueprint, jsonify, request
from datetime import datetime

from server.modules.devices.models.device import Device
from server.modules.communication.models.rflog import RFLog
from server.modules.automation.evaluator import evaluator
from server.db.database import Database

communication_bp = Blueprint('communication_api', __name__)

@communication_bp.route("/ingest", methods=["POST"])
def api_ingest():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "bad request"}), 400

    # Soporte para paquetes RAW de RF24Mesh (origin, cmd, data)
    if "origin" in data and "cmd" in data:
        node_id = data["origin"]
        cmd = data["cmd"]
        raw_data = data.get("data", [])
        device_id = f"dev_{node_id}"
        
        dev = Device.get(device_id)
        
        if cmd == 5: # CMD_DISCOVER
            # Parsear Payload: data[0] = len, data[1..15] = name, data[16] = feature bitmask
            if len(raw_data) >= 17:
                name_len = raw_data[0]
                name_chars = raw_data[1:1+name_len]
                device_name = "".join([chr(c) for c in name_chars if c != 0])
                features = raw_data[16]
                
                # Crear o actualizar el dispositivo
                if not dev:
                    dev = Device(device_id=device_id)
                dev.name = device_name
                
                current_state = dev.state if isinstance(dev.state, dict) else {}
                
                if features & 0x01: # RELAY
                    if "on" not in current_state: current_state["on"] = False
                if features & 0x02: # BRIGHTNESS
                    if "brightness" not in current_state: current_state["brightness"] = 0
                if features & 0x04: # TEMP
                    if "temperature" not in current_state: current_state["temperature"] = 0.0
                if features & 0x08: # HUMIDITY
                    if "humidity" not in current_state: current_state["humidity"] = 0.0
                    
                dev.state = current_state
                dev.status = "online"
                dev.save()
                
                return jsonify({"ok": True, "action": "discovered"})
                
        else:
            # TODO: Parsear otros comandos (HEARTBEAT, REPORT)
            payload = {} # Deberíamos parsearlo
            rssi = 0
    else:
        # Formato de capa superior (App / Bridge ya procesado)
        if "id" not in data:
            return jsonify({"error": "missing id"}), 400
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
    
    dev.update(payload, rssi if 'rssi' in locals() else 0)

    log = RFLog(
        ts=datetime.now().isoformat(),
        device_id=device_id,
        rssi=rssi if 'rssi' in locals() else 0,
        payload=payload,
        direction="RX"
    )
    log.save()

    # Disparar Motor de Automatización en Tiempo Real
    evaluator.evaluate_event(device_id, payload)

    return jsonify({"ok": True})


@communication_bp.route("/command", methods=["POST"])
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


@communication_bp.route("/stats", methods=["GET"])
def api_stats():
    devices = Device.all()
    online = sum(1 for d in devices if d.status == "online")
    cursor = Database.execute("SELECT COUNT(*) as c FROM rf_logs")
    log_count = cursor.fetchone()["c"]
    
    return jsonify({
        "total":   len(devices),
        "online":  online,
        "offline": len(devices) - online,
        "log_len": log_count,
    })
