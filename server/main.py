"""
IoT RF Gateway Server - main.py
Backend ultra-liviano para Raspberry Pi
Comunicación por radiofrecuencia (RF433/nRF24/LoRa)
"""
from flask import Flask
from datetime import datetime
import os
import sys
from pathlib import Path

# Agregar ruta raíz al path para importar modulos
sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))

from server.core.config import API_PORT
from server.db.database import BaseModel
from server.modules.devices.models.device import Device
from server.modules.automation.evaluator import evaluator
from server.modules.devices.models.device import Device

from server.modules.automation.evaluator import evaluator

from server.modules.devices.routes.api import devices_bp
from server.modules.devices.routes.views import devices_view_bp
from server.modules.automation.routes.api import automation_bp
from server.modules.automation.routes.views import automation_view_bp
from server.modules.communication.routes.api import communication_bp
from server.modules.communication.routes.views import communication_view_bp
from server.modules.communication.logic.watchdog import start_watchdog

app = Flask(__name__)
app.register_blueprint(devices_bp, url_prefix="/api")
app.register_blueprint(devices_view_bp)
app.register_blueprint(automation_bp, url_prefix="/api")
app.register_blueprint(automation_view_bp)
app.register_blueprint(communication_bp, url_prefix="/api")
app.register_blueprint(communication_view_bp)

start_watchdog()
evaluator.start()


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




if __name__ == "__main__":
    app.run(host="0.0.0.0", port=API_PORT, debug=False, threaded=True)
