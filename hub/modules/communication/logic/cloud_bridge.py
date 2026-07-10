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
        url = bridge_url or os.environ.get("CLOUD_SERVER_URL") or os.environ.get("CLOUD_BRIDGE_URL", "http://127.0.0.1:8000")
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

    def _get_headers(self):
        return {
            "Content-Type": "application/json",
            "X-Hub-Id": os.environ.get("HUB_ID", ""),
            "X-Hub-Secret": os.environ.get("HUB_RELAY_SECRET", "")
        }

    def _loop(self):
        # Pequeño retraso inicial para permitir que el Hub levante la DB
        time.sleep(2)
        while self.running:
            try:
                if not os.environ.get("HUB_ID"):
                    # Si el hub no está vinculado, no hace polling
                    time.sleep(5)
                    continue

                # 1. Sincronizar catálogo de dispositivos cada 15 segundos hacia el servidor exterior
                now = time.time()
                if now - self.last_sync > 15.0:
                    self._sync_devices()
                    self.last_sync = now

                # 2. Consultar salientemente por peticiones pendientes (Long-Polling)
                r = requests.get(f"{self.bridge_url}/api/hub/poll", headers=self._get_headers(), timeout=5)
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
                            headers=self._get_headers(),
                            timeout=3
                        )
                        print(f"📤 [CLOUD BRIDGE] Confirmación enviada al Bridge Server ✔️\n")
                elif r.status_code == 401:
                    print(f"⚠️ [CLOUD BRIDGE] Hub no autorizado. Verifica HUB_ID y HUB_RELAY_SECRET.")
                    time.sleep(10) # Backoff on auth error

            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError, requests.exceptions.RequestException):
                # Si el servidor cloud (o VPS) no está accesible o el dominio aún no se configura, esperar en silencio
                time.sleep(5)
            except Exception as e:
                # Solo mostrar error si es algo excepcional de lógica de programación
                print(f"⚠️ [CLOUD BRIDGE] Error interno: {e}")
                time.sleep(5)

    def _sync_devices(self):
        """Envía la lista actual de dispositivos al Bridge Server para caché"""
        try:
            devices = [d.to_dict() for d in Device.all()]
            requests.post(
                f"{self.bridge_url}/api/hub/sync",
                json={"devices": devices, "ts": datetime.now().isoformat()},
                headers=self._get_headers(),
                timeout=3
            )
        except Exception:
            pass

    def _execute_local_command(self, payload):
        """Ejecuta la lógica real que antes residía solo en las rutas REST locales del Hub"""
        device_id = payload.get("id")
        cmd = payload.get("cmd", "set")
        params = payload.get("params", {})
        action = payload.get("action", "")

        # 1. Comandos de emparejamiento RF (Pairing Mode)
        if cmd == "pairing" or cmd in ("pairing_start", "pairing_stop") or (cmd == "set" and action in ("start", "stop")):
            if not gateway.is_connected:
                return {"ok": False, "error": "Gateway no conectado"}
            if action == "start" or cmd == "pairing_start":
                gateway.last_paired_device = None
                res = gateway.send_command(0x00, 0x0D)
                print(f"📡 [CLOUD BRIDGE] Modo emparejamiento RF INICIADO por orden remota")
                return {"ok": res, "mode": "pairing_started", "status": "active"}
            elif action == "stop" or cmd == "pairing_stop":
                gateway.pairing_start_time = 0
                res = gateway.send_command(0x00, 0x0E)
                print(f"📡 [CLOUD BRIDGE] Modo emparejamiento RF DETENIDO por orden remota")
                return {"ok": res, "mode": "pairing_stopped", "status": "idle"}

        if cmd == "pairing_status":
            elapsed = int(time.time() - gateway.pairing_start_time) if gateway.pairing_start_time > 0 else 0
            return {
                "ok": True,
                "status": gateway.pairing_status,
                "last_tx": gateway.last_tx,
                "last_rx": gateway.last_rx,
                "elapsed": elapsed,
                "last_device": gateway.last_paired_device
            }

        # 2. Sincronización y Registro de dispositivos vía Relay
        if cmd in ("sync_devices", "get_devices"):
            devices = [d.to_dict() for d in Device.all()]
            return {"ok": True, "devices": devices}

        if cmd in ("register_device", "update_device"):
            reg_id = payload.get("device_id") or payload.get("id")
            if not reg_id:
                return {"ok": False, "error": "device_id requerido"}
            dev = Device.get(reg_id) or Device(device_id=reg_id)
            if "name" in payload: dev.name = payload["name"]
            if "type_name" in payload: dev.type_name = payload["type_name"]
            if "category" in payload: dev.category = payload["category"]
            if "room" in payload: dev.category = payload["room"]
            if "state" in payload and isinstance(payload["state"], dict):
                dev.state = payload["state"]
            dev.status = "online"
            dev.save()
            self._sync_devices()
            print(f"🏠 [CLOUD BRIDGE] Dispositivo actualizado/registrado: '{dev.name}' ({dev.device_id})")
            return {"ok": True, "device": dev.to_dict()}

        if cmd == "delete_device":
            del_id = payload.get("device_id") or payload.get("id")
            if not del_id:
                return {"ok": False, "error": "device_id requerido para eliminar"}
            dev = Device.get(del_id)
            if dev:
                dev.delete()
                print(f"🗑️ [CLOUD BRIDGE] Dispositivo eliminado: '{del_id}'")
            self._sync_devices()
            return {"ok": True, "deleted": del_id}

        dev = Device.get(device_id)
        if not dev and not str(device_id).startswith("dev_"):
            dev = Device.get(f"dev_{device_id}")
        if not dev and str(device_id).startswith("dev_"):
            dev = Device.get(str(device_id).split("_", 1)[1])
        if not dev:
            dev = Device(device_id=str(device_id), name=f"Device {device_id}", status="online")
            dev.save()

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
                dest_id = 0
                if str(device_id).startswith("dev_"):
                    dest_id = int(str(device_id).split("_")[1])
                elif str(device_id).isdigit():
                    dest_id = int(str(device_id))
                
                if dest_id > 0:
                    state_dict = dev.state if isinstance(dev.state, dict) else {}
                    ch1 = 1 if params.get("ch1", params.get("on", state_dict.get("ch1", state_dict.get("on", False)))) else 0
                    ch2 = 1 if params.get("ch2", state_dict.get("ch2", False)) else 0
                    ch3 = 1 if params.get("ch3", state_dict.get("ch3", False)) else 0
                    ch4 = 1 if params.get("ch4", state_dict.get("ch4", False)) else 0
                    
                    # Comando 0x06 (CONTROL) con estados de canales
                    gateway.send_command(dest_id=dest_id, command=0x06, device_type=getattr(dev, "device_type", 0) or 0, data=[ch1, ch2, ch3, ch4])
                    
                    # Si es comando específico de encendido/apagado general o 1 canal
                    if "on" in params and not any(k in params for k in ("ch1", "ch2", "ch3", "ch4")):
                        cmd_byte = 0x01 if params["on"] else 0x02
                        gateway.send_command(dest_id=dest_id, command=cmd_byte, device_type=getattr(dev, "device_type", 0) or 0, data=[ch1, ch2, ch3, ch4])
            except Exception as e:
                print(f"⚠️ [GATEWAY TX] Advertencia al transmitir por hardware: {e}")

        print(f"🏠 [HUB NATIVO] Dispositivo '{dev.name}' actualizado a: {params}")
        return {"ok": True, "state": dev.state, "device": dev.to_dict()}

cloud_bridge = CloudBridgeWorker()
