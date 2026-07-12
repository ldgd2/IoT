from flask import Blueprint, render_template, session
from hub.modules.devices.models.device import Device
from hub.modules.auth.models.room import Room

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

@devices_view_bp.route("/rooms")
def rooms_view():
    user_id = session.get("user_id", "")
    rooms = Room.get_by_user(user_id)
    return render_template("views/dashboard/rooms/index.html", rooms=rooms)

@devices_view_bp.route("/rooms/<room_id>")
def room_detail(room_id):
    room = Room.get_by_id(room_id)
    if not room:
        return "Room not found", 404
    
    # Optional: fetch devices that belong to this room, if your schema supports it.
    # Currently devices don't have a room_id field by default, we'll fetch all or mock.
    # For now we'll pass devices to the template.
    all_devices = Device.all()
    # If device schema had room_id, we'd do: room_devices = [d for d in all_devices if getattr(d, 'room_id', None) == room_id]
    room_devices = all_devices # Showing all as demo if filtering isn't implemented
    
    return render_template("views/dashboard/rooms/view.html", room=room, devices=room_devices)


@devices_view_bp.route("/guide")
def guide_view():
    return render_template("views/dashboard/guide/index.html")
