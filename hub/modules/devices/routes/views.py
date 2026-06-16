from flask import Blueprint, render_template
from hub.modules.devices.models.device import Device

devices_view_bp = Blueprint('devices_view', __name__)

@devices_view_bp.route("/")
def dashboard():
    return render_template("views/dashboard/index.html", devices=Device.all())

@devices_view_bp.route("/devices")
def devices_view():
    return render_template("views/dashboard/devices/index.html", devices=Device.all())

@devices_view_bp.route("/device/<device_id>")
def device_detail(device_id):
    dev = Device.get(device_id)
    if not dev:
        return "Device not found", 404
    return render_template("views/dashboard/devices/detail.html", device=dev)

@devices_view_bp.route("/devices/new")
def devices_wizard_view():
    return render_template("views/dashboard/devices/wizard.html")
