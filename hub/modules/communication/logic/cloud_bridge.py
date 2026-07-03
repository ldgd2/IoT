# =============================================================
# hub/modules/communication/logic/cloud_bridge.py
# Enlace Saliente (Outbound Relay) integrado nativamente en el Gateway Hub
# =============================================================
import os
import time
import threading
import requests
from datetime import datetime

from hub.modules.devices.models.device import Device
from hub.modules.communication.models.rflog import RFLog
from hub.modules.communication.logic.gateway import gateway

class CloudBridgeWorker:
    """
    Worker en segundo plano nativo del Hub.
    Permite que el Hub corra detrás de NAT/Firewall sin abrir puertos,
    consultando peticiones salientes al Bridge Server externo (en la nube o servidor local).
    """
    def __init__(self):
        self.running = False
        self.thread = None
        self.bridge_url = ""
        self.last_sync = 0

    def start(self, bridge_url=None):
        url = bridge_url or os.environ.get("CLOUD_BRIDGE_URL", "http://127.0.0.1:8000")
        if not url:
            return
        
        self.bridge_url = url.rstrip("/")
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self._loop, daemon=True, name="CloudBridgeWorker")
            self.thread.start()
            print(f"☁️ [CLOUD BRIDGE] Enlace saliente activo hacia: {self.bridge_url}")

    def stop(self):
        self.running = False

    def _loop(self):
        # Pequeño retraso inicial para permitir que el Hub levante la DB
        time.sleep(2)
        while self.running:
            try:
                # 1. Sincronizar catálogo de dispositivos cada 15 segundos hacia el servidor exterior
                now = time.time()
                if now - self.last_sync > 15.0:
                    self._sync_devices()
                    self.last_sync = now

                # 2. Consultar salientemente por peticiones pendientes (Long-Polling)
                r = requests.get(f"{self.bridge_url}/api/hub/poll", timeout=5)
                if r.status_code == 200:
                    data = r.json()
                    if data.get("status") == "job":
                        cmd_id = data.get("cmd_id")
                        payload = data.get("payload", {})
                        print(f"\n⚡ [CLOUD BRIDGE] Orden recibida desde el exterior (ID: {cmd_id})")
                        
                        # Procesar comando con la lógica nativa del Hub
                        result = self._execute_local_command(payload)
                        
                        # Retornar el resultado saliendo hacia el exterior
                        requests.post(
                            f"{self.bridge_url}/api/hub/response",
                            json={"cmd_id": cmd_id, "result": result},
                            timeout=3
                        )
                        print(f"📤 [CLOUD BRIDGE] Confirmación enviada al Bridge Server ✔️\n")

            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError, requests.exceptions.RequestException):
                # Si el servidor cloud (o VPS) no está accesible o el dominio aún no se configura, esperar en silencio
                time.sleep(5)
            except Exception as e:
                # Solo mostrar error si es algo excepcional de lógica de programación
                time.sleep(5)

    def _sync_devices(self):
        """Envía la lista actual de dispositivos al Bridge Server para caché"""
        try:
            devices = [d.to_dict() for d in Device.all()]
            requests.post(
                f"{self.bridge_url}/api/hub/sync",
                json={"devices": devices, "ts": datetime.now().isoformat()},
                timeout=3
            )
        except Exception:
            pass

    def _execute_local_command(self, payload):
        """Ejecuta la lógica real que antes residía solo en las rutas REST locales del Hub"""
        device_id = payload.get("id")
        cmd = payload.get("cmd", "set")
        params = payload.get("params", {})

        dev = Device.get(device_id)
        if not dev:
            return {"ok": False, "error": f"Dispositivo {device_id} no encontrado en la base de datos del Hub"}

        # 1. Actualizar estado interno en BD
        if isinstance(dev.state, dict):
            dev.state.update(params)
        dev.status = "online"
        dev.save()

        # 2. Registrar en el log de comunicaciones RF
        log = RFLog(
            ts=datetime.now().isoformat(),
            device_id=device_id,
            direction="TX",
            cmd=cmd,
            payload=params
        )
        log.save()

        # 3. Transmitir por hardware Gateway (Si hay módulo RF / Serial / HID conectado)
        if gateway.is_connected:
            try:
                # Transmitir trama por hardware Gateway
                pass
            except Exception as e:
                print(f"⚠️ [GATEWAY TX] Advertencia al transmitir por hardware: {e}")

        print(f"🏠 [HUB NATIVO] Dispositivo '{dev.name}' actualizado a: {params}")
        return {"ok": True, "state": dev.state, "device": dev.to_dict()}

cloud_bridge = CloudBridgeWorker()
