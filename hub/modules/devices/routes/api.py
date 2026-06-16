from flask import Blueprint, jsonify
from hub.modules.devices.models.device import Device

devices_bp = Blueprint('devices_api', __name__)

@devices_bp.route("/devices", methods=["GET"])
def api_devices():
    return jsonify([d.to_dict() for d in Device.all()])

@devices_bp.route("/device/<device_id>", methods=["GET"])
def api_device(device_id):
    dev = Device.get(device_id)
    if not dev:
        return jsonify({"error": "not found"}), 404
    return jsonify(dev.to_dict())
