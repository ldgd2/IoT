from flask import Blueprint, jsonify, request
from hub.modules.devices.models.device import Device

devices_bp = Blueprint('devices_api', __name__)

@devices_bp.route("/devices", methods=["GET"])
def api_devices():
    return jsonify([d.to_dict() for d in Device.all()])

@devices_bp.route("/devices", methods=["POST"])
def api_create_device():
    """Crea o actualiza un dispositivo en la base de datos del Hub.
    Llamado desde la app Flutter cuando el usuario vincula un dispositivo manualmente.
    Body JSON: { device_id, name, type_name, category, room, rssi }
    """
    data = request.get_json(silent=True) or {}
    device_id = (data.get("device_id") or "").strip()
    if not device_id:
        return jsonify({"error": "device_id requerido"}), 400

    dev = Device.get(device_id)
    if not dev:
        dev = Device(device_id=device_id)

    if "name" in data and data["name"].strip():
        dev.name = data["name"].strip()
    if "type_name" in data:
        dev.type_name = data["type_name"]
    if "category" in data:
        dev.category = data["category"]
    if "room" in data:
        # Guardamos la habitacion en el campo category si no hay campo room dedicado
        dev.category = data["room"]
    if "rssi" in data:
        dev.rssi = int(data["rssi"]) if data["rssi"] is not None else 0
    if "state" in data and isinstance(data["state"], dict):
        dev.state = data["state"]

    import datetime
    dev.last_seen = datetime.datetime.now().isoformat()
    dev.status = "online"
    dev.save()

    try:
        from hub.modules.communication.logic.cloud_bridge import cloud_bridge
        cloud_bridge._sync_devices()
    except Exception:
        pass

    return jsonify({"ok": True, "device": dev.to_dict()}), 201

@devices_bp.route("/device/<device_id>", methods=["GET"])
@devices_bp.route("/devices/<device_id>", methods=["GET"])
def api_device(device_id):
    dev = Device.get(device_id)
    if not dev:
        return jsonify({"error": "not found"}), 404
    return jsonify(dev.to_dict())

@devices_bp.route("/device/<device_id>", methods=["PUT", "POST", "PATCH"])
@devices_bp.route("/devices/<device_id>", methods=["PUT", "POST", "PATCH"])
def api_update_device(device_id):
    from flask import request
    data = request.get_json(silent=True) or {}
    dev = Device.get(device_id)
    if not dev:
        # Upsert: si no existe, lo crea en lugar de devolver 404
        dev = Device(device_id=device_id)
    if "name" in data and data["name"].strip():
        dev.name = data["name"].strip()
    if "category" in data:
        dev.category = data["category"]
    if "room" in data:
        dev.category = data["room"]
    if "type_name" in data:
        dev.type_name = data["type_name"]
    if "state" in data and isinstance(data["state"], dict):
        dev.state = data["state"]
    dev.save()

    try:
        from hub.modules.communication.logic.cloud_bridge import cloud_bridge
        cloud_bridge._sync_devices()
    except Exception:
        pass

    return jsonify({"ok": True, "device": dev.to_dict()})

@devices_bp.route("/device/<device_id>", methods=["DELETE"])
@devices_bp.route("/devices/<device_id>", methods=["DELETE"])
def api_delete_device(device_id):
    dev = Device.get(device_id)
    if not dev:
        return jsonify({"error": "not found"}), 404
    dev.delete()

    try:
        from hub.modules.communication.logic.cloud_bridge import cloud_bridge
        cloud_bridge._sync_devices()
    except Exception:
        pass

    return jsonify({"ok": True})
