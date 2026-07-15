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
from hub.modules.automation.models.skill import Skill
from hub.modules.communication.models.notification import NotificationLog

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
        self.stats = {
            "polls_sent": 0,
            "syncs_sent": 0,
            "commands_executed": 0,
            "last_sync_time": "Pendiente",
            "last_poll_time": "Pendiente",
            "status": "Inactivo"
        }

    def start(self, bridge_url=None):
        url = bridge_url or os.environ.get("CLOUD_SERVER_URL") or os.environ.get("CLOUD_BRIDGE_URL", "http://127.0.0.1:8000")
        if not url:
            return
        
        url = url.rstrip("/")
        if url.endswith("/api"):
            url = url[:-4]
        self.bridge_url = url.rstrip("/")
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self._loop, daemon=True, name="CloudBridgeWorker")
            self.thread.start()
            print(f"[CLOUD BRIDGE] Enlace saliente activo hacia: {self.bridge_url}")

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
                self.stats["polls_sent"] += 1
                self.stats["last_poll_time"] = datetime.now().strftime("%H:%M:%S")
                self.stats["status"] = "Conectado al Cloud"
                r = requests.get(f"{self.bridge_url}/api/hub/poll", headers=self._get_headers(), timeout=5)
                if r.status_code == 200:
                    data = r.json()
                    if data.get("status") == "job":
                        cmd_id = data.get("cmd_id")
                        payload = data.get("payload", {})
                        cmd_name = payload.get("cmd", "")
                        if cmd_name != "pairing_status":
                            print(f"\n [CLOUD BRIDGE] Orden recibida desde el exterior (ID: {cmd_id} | CMD: {cmd_name})")
                        
                        # Procesar comando con la lógica nativa del Hub
                        result = self._execute_local_command(payload)
                        self.stats["commands_executed"] += 1
                        
                        # Retornar el resultado saliendo hacia el exterior
                        requests.post(
                            f"{self.bridge_url}/api/hub/response",
                            headers=self._get_headers(),
                            json={"cmd_id": cmd_id, "result": result},
                            timeout=5
                        )
                        if cmd_name != "pairing_status":
                            print(f"[CLOUD BRIDGE] Confirmación enviada al Bridge Server\n")
                elif r.status_code == 401:
                    err_code = ""
                    try:
                        err_code = r.json().get("code", "")
                    except Exception:
                        pass
                    if err_code == "HUB_UNLINKED" or not err_code:
                        print("[CLOUD BRIDGE] Hub no autorizado o desvinculado por el servidor exterior. Pausando polling saliente...")
                        self.stats["status"] = "Desvinculado / No Autorizado"
                        os.environ.pop("HUB_ID", None)
                        os.environ.pop("HUB_RELAY_SECRET", None)
                        if err_code == "HUB_UNLINKED":
                            try:
                                from dotenv import unset_key
                                from pathlib import Path
                                env_file = Path(__file__).parent.parent.parent.parent / ".env"
                                if env_file.exists():
                                    unset_key(str(env_file), "HUB_ID")
                                    unset_key(str(env_file), "HUB_RELAY_SECRET")
                            except Exception as e:
                                print(f"[CLOUD BRIDGE] Error al limpiar archivo .env: {e}")
                    time.sleep(5) # Pausar y esperar que se vuelva a vincular

            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError, requests.exceptions.RequestException):
                self.stats["status"] = "Esperando Conexión Nube"
                time.sleep(5)
            except Exception as e:
                print(f"[CLOUD BRIDGE] Error interno: {e}")
                time.sleep(5)

    def _sync_devices(self):
        """Envía la lista actual de dispositivos al Bridge Server para caché"""
        if not os.environ.get("HUB_ID") or not getattr(self, "bridge_url", None):
            return
        try:
            devices = [d.to_dict() for d in Device.all()]
            requests.post(
                f"{self.bridge_url}/api/hub/sync",
                json={"devices": devices, "ts": datetime.now().isoformat()},
                headers=self._get_headers(),
                timeout=3
            )
            self.stats["syncs_sent"] += 1
            self.stats["last_sync_time"] = datetime.now().strftime("%H:%M:%S")
        except Exception:
            self.stats["status"] = "Sin conexión al servidor Sync"
            pass

    def send_event(self, event_type, payload):
        """Notifica eventos instantáneos del Hub al Servidor exterior (ej. device_paired, device_unpaired)"""
        if not os.environ.get("HUB_ID") or not getattr(self, "bridge_url", None):
            return
        try:
            self._sync_devices()
            requests.post(
                f"{self.bridge_url}/api/hub/event",
                json={"event": event_type, "payload": payload, "ts": datetime.now().isoformat()},
                headers=self._get_headers(),
                timeout=4
            )
            print(f"[CLOUD BRIDGE] Evento saliente '{event_type}' notificado al servidor en nube.")
        except Exception as e:
            print(f"[CLOUD BRIDGE] Error al notificar evento '{event_type}': {e}")


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
                print(f"[CLOUD BRIDGE] Modo emparejamiento RF INICIADO por orden remota")
                return {"ok": res, "mode": "pairing_started", "status": "active"}
            elif action == "stop" or cmd == "pairing_stop":
                gateway.pairing_start_time = 0
                res = gateway.send_command(0x00, 0x0E)
                print(f"[CLOUD BRIDGE] Modo emparejamiento RF DETENIDO por orden remota")
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

        # 2. Comandos de Skills / Escenas vía Relay
        if cmd in ("skills", "get_skills"):
            try:
                skills = [s.to_dict() for s in Skill.all()]
                return {"ok": True, "skills": skills}
            except Exception as e:
                return {"ok": False, "error": str(e), "skills": []}

        if cmd in ("save_skill", "create_skill"):
            try:
                s_id = payload.get("id") or payload.get("skill_id")
                skill = Skill.get(s_id) if s_id else Skill()
                if "name" in payload: skill.name = payload["name"]
                if "ast_json" in payload: skill.ast_json = payload["ast_json"]
                if "is_active" in payload: skill.is_active = int(payload["is_active"])
                if not skill.created_at: skill.created_at = datetime.now().isoformat()
                skill.save()
                return {"ok": True, "skill": skill.to_dict()}
            except Exception as e:
                return {"ok": False, "error": str(e)}

        if cmd == "toggle_skill":
            try:
                s_id = payload.get("skill_id") or payload.get("id")
                if not s_id: return {"ok": False, "error": "skill_id requerido"}
                skill = Skill.get(s_id)
                if not skill: return {"ok": False, "error": "Skill no encontrada"}
                if "is_active" in payload:
                    skill.is_active = 1 if payload["is_active"] else 0
                else:
                    skill.is_active = 0 if skill.is_active else 1
                skill.save()
                return {"ok": True, "skill": skill.to_dict()}
            except Exception as e:
                return {"ok": False, "error": str(e)}

        if cmd == "delete_skill":
            try:
                s_id = payload.get("skill_id") or payload.get("id")
                if not s_id: return {"ok": False, "error": "skill_id requerido"}
                skill = Skill.get(s_id)
                if skill: skill.delete()
                return {"ok": True, "deleted": s_id}
            except Exception as e:
                return {"ok": False, "error": str(e)}

        if cmd == "execute_skill":
            try:
                s_id = payload.get("skill_id") or payload.get("id")
                if not s_id: return {"ok": False, "error": "skill_id requerido"}
                skill = Skill.get(s_id)
                if not skill: return {"ok": False, "error": "Skill no encontrada"}
                from hub.modules.automation.evaluator import SkillEvaluator
                actions = skill.ast_json.get("actions", []) if isinstance(skill.ast_json, dict) else []
                SkillEvaluator.execute_actions(actions)
                return {"ok": True, "executed": s_id}
            except Exception as e:
                return {"ok": False, "error": str(e)}

        # 3. Comandos de Estado del Hub (Stats) y Notificaciones
        if cmd == "stats":
            return {
                "status": "ok",
                "hub": "Colmena Hub",
                "online": True,
                "gateway_connected": gateway.is_connected,
                "pairing_status": gateway.pairing_status,
                "rssi": getattr(gateway, "rssi", -65)
            }

        if cmd in ("notifications", "get_notifications"):
            try:
                logs = [l.to_dict() for l in NotificationLog.all()]
                return {"ok": True, "notifications": logs}
            except Exception as e:
                return {"ok": True, "notifications": []}

        # 4. Sincronización y Registro de dispositivos vía Relay
        if cmd in ("sync_devices", "get_devices"):
            devices = [d.to_dict() for d in Device.all()]
            return {"ok": True, "devices": devices}

        if cmd == "get_device":
            reg_id = payload.get("device_id") or payload.get("id")
            dev = Device.get(reg_id) if reg_id else None
            if not dev and str(reg_id).startswith("dev_"):
                dev = Device.get(str(reg_id).split("_", 1)[1])
            if not dev and not str(reg_id).startswith("dev_"):
                dev = Device.get(f"dev_{reg_id}")
            if not dev:
                return {"ok": False, "error": "not found"}
            return {"ok": True, "device": dev.to_dict()}

        if cmd in ("register_device", "update_device"):
            reg_id = payload.get("device_id") or payload.get("id")
            if not reg_id:
                return {"ok": False, "error": "device_id requerido"}
            dev = Device.get(reg_id) or Device(device_id=reg_id)
            if "name" in payload: dev.name = payload["name"]
            if "type_name" in payload: dev.type_name = payload["type_name"]
            if "category" in payload: dev.category = payload["category"]
            if "room" in payload: dev.room = payload["room"]
            if "state" in payload and isinstance(payload["state"], dict):
                if isinstance(dev.state, dict): dev.state.update(payload["state"])
                else: dev.state = payload["state"]
            dev.status = "online"
            dev.save()
            self._sync_devices()
            if cmd == "update_device" and "state" in payload and isinstance(payload["state"], dict):
                self._execute_local_command({"id": reg_id, "cmd": "set", "params": payload["state"]})
            print(f"🏠 [CLOUD BRIDGE] Dispositivo actualizado/registrado: '{dev.name}' ({dev.device_id})")
            return {"ok": True, "device": dev.to_dict()}

        if cmd == "delete_device":
            del_id = payload.get("device_id") or payload.get("id")
            if not del_id:
                return {"ok": False, "error": "device_id requerido para eliminar"}
            dev = Device.get(del_id)
            if dev:
                dev.delete()
                print(f"[CLOUD BRIDGE] Dispositivo eliminado: '{del_id}'")
            try:
                node_num = int(str(del_id).replace("dev_", ""))
                gateway.send_command(dest_id=node_num, command=0x0F, device_type=0, data=[0]*8)
                print(f"[CLOUD BRIDGE] CMD_UNPAIR (0x0F) enviado al Gateway para desvincular el Nodo {node_num}")
            except Exception as e:
                print(f"[CLOUD BRIDGE] No se pudo enviar CMD_UNPAIR al Gateway: {e}")
            self._sync_devices()
            return {"ok": True, "deleted": del_id}

        if not device_id:
            return {"ok": False, "error": f"Comando sin id de dispositivo no reconocido: '{cmd}'"}

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
        dev.update(dev.state if isinstance(dev.state, dict) else params)

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
                    try: dest_id = int(str(device_id).split("_")[1])
                    except ValueError: pass
                if dest_id == 0 and str(device_id).isdigit():
                    dest_id = int(str(device_id))
                if dest_id == 0:
                    import re
                    m = re.search(r'\d+$', str(device_id))
                    if m: dest_id = int(m.group(0))
                
                if dest_id > 0:
                    state_dict = dev.state if isinstance(dev.state, dict) else {}
                    mask = params.get("mask", state_dict.get("mask", 0))
                    if not isinstance(mask, int):
                        mask = int(mask) if str(mask).isdigit() else 0
                    
                    # Sincronizar mask con cualquier canal individual ('chX') existente o recibido
                    all_keys = set(state_dict.keys()) | set(params.keys())
                    for k in all_keys:
                        if k.startswith("ch") and k[2:].isdigit():
                            ch_num = int(k[2:])
                            if ch_num >= 1:
                                val = params.get(k, state_dict.get(k, False))
                                if val:
                                    mask |= (1 << (ch_num - 1))
                                else:
                                    mask &= ~(1 << (ch_num - 1))
                    
                    # Si es orden general 'on' sin canales individuales especificados
                    if "on" in params and not any(k.startswith("ch") and k[2:].isdigit() for k in params.keys()):
                        if params["on"]:
                            mask = 1 if mask == 0 else mask | 1
                        else:
                            mask = 0
                            
                    data_payload = [
                        mask & 0xFF,
                        (mask >> 8) & 0xFF,
                        (mask >> 16) & 0xFF,
                        (mask >> 24) & 0xFF
                    ]
                    for i in range(22):
                        data_payload.append(1 if (mask & (1 << i)) else 0)
                    if "brightness" in params:
                        try: data_payload[1] = int(params["brightness"]) & 0xFF
                        except Exception: pass
                    
                    t_code = getattr(dev, "type_code", 0) or 0
                    gateway.send_command(dest_id=dest_id, command=0x10, device_type=t_code, data=data_payload)
                    
                    if "on" in params and not any(k.startswith("ch") and k[2:].isdigit() for k in params.keys()):
                        cmd_byte = 0x01 if params["on"] else 0x02
                        gateway.send_command(dest_id=dest_id, command=cmd_byte, device_type=t_code, data=data_payload)
            except Exception as e:
                print(f"[GATEWAY TX] Advertencia al transmitir por hardware: {e}")

        print(f"[HUB NATIVO] Dispositivo '{dev.name}' actualizado a: {params}")
        return {"ok": True, "state": dev.state, "device": dev.to_dict()}

cloud_bridge = CloudBridgeWorker()
