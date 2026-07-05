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

import io
if os.getenv("HUB_BACKGROUND") == "1":
    log_dir = Path(__file__).parent.parent / "logs"
    log_dir.mkdir(exist_ok=True)
    log_file = open(log_dir / "hub.log", "a", encoding="utf-8", buffering=1)
    sys.stdout = log_file
    sys.stderr = log_file
elif sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')


from hub.core.config import API_PORT
from hub.db.database import BaseModel
from hub.modules.devices.models.device import Device
from hub.modules.automation.evaluator import evaluator
from hub.modules.devices.models.device import Device

from hub.modules.automation.evaluator import evaluator

from hub.modules.devices.routes.api import devices_bp
from hub.modules.devices.routes.views import devices_view_bp
from hub.modules.automation.routes.api import automation_bp
from hub.modules.automation.routes.views import automation_view_bp
from hub.modules.communication.routes.api import communication_bp, process_incoming_packet
from hub.modules.communication.routes.views import communication_view_bp
from hub.modules.communication.logic.watchdog import start_watchdog
from hub.modules.communication.logic.gateway import gateway
from hub.modules.communication.logic.cloud_bridge import cloud_bridge

app = Flask(__name__)
app.register_blueprint(devices_bp, url_prefix="/api")
app.register_blueprint(devices_view_bp)
app.register_blueprint(automation_bp, url_prefix="/api")
app.register_blueprint(automation_view_bp)
app.register_blueprint(communication_bp, url_prefix="/api")
app.register_blueprint(communication_view_bp)

start_watchdog()
evaluator.start()
cloud_bridge.start()

# Iniciar Gateway Real (RF)
if gateway.connect():
    gateway.on_packet_received = process_incoming_packet
    gateway.start_listening()
    print("📡 Gateway RF Conectado y escuchando...")
else:
    print("⚠️ Gateway RF No conectado. Revisa tu puerto USB/COM.")

# Aseguramos de que las tablas existan al inicio invocando al padre
BaseModel.migrate_all()






if __name__ == "__main__":
    app.run(host="0.0.0.0", port=API_PORT, debug=False, threaded=True)
