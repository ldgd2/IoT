from flask import Blueprint, jsonify, request
from datetime import datetime
import serial.tools.list_ports

from hub.core.config import ENV_FILE
from hub.modules.devices.models.device import Device
from hub.modules.communication.models.rflog import RFLog
from hub.modules.automation.evaluator import evaluator
from hub.db.database import Database
from hub.core.device_types import DeviceRegistry

communication_bp = Blueprint('communication_api', __name__)

def process_incoming_packet(data):
    if not data:
        return {"error": "bad request"}, 400

    # Soporte para paquetes RAW de RF24Mesh (origin, cmd, data)
    if "origin" in data and "cmd" in data:
        node_id = data["origin"]
        cmd = data["cmd"]
        raw_data = data.get("data", [])
        device_id = f"dev_{node_id}"
        
        dev = Device.get(device_id)
        
        if cmd == 5: # CMD_DISCOVER
            if len(raw_data) >= 17:
                name_len = raw_data[0]
                name_chars = raw_data[1:1+name_len]
                device_name = "".join([chr(c) for c in name_chars if c != 0])
                features = raw_data[16]
                device_type = data.get("type", 0)
                
                reg_info = DeviceRegistry.describe(device_type, features)
                from hub.modules.communication.logic.gateway import gateway
                
                if not dev:
                    if gateway.pairing_status not in ("active", "success"):
                        # Si llega CMD_DISCOVER de un nodo RF desconocido y el Hub NO está en modo vinculación, no lo creamos en la interfaz
                        log = RFLog(
                            ts=datetime.now().isoformat(),
                            device_id=device_id,
                            rssi=0,
                            payload={"warn": "ignored_discover_not_pairing"},
                            direction="RX"
                        )
                        log.save()
                        return {"ok": True, "action": "ignored_not_pairing"}, 200
                    dev = Device(device_id=device_id)
                
                dev.name = device_name
                dev.type_code = reg_info["type_code"]
                dev.type_name = reg_info["type_name"]
                dev.type_icon = reg_info["type_icon"]
                dev.category = reg_info["category"]
                dev.features = reg_info["features"]
                dev.feature_keys = reg_info["feature_keys"]
                
                current_state = dev.state if isinstance(dev.state, dict) else {}
                
                # Inicializacion dinamica de estado basado en feature keys
                keys = reg_info["feature_keys"]
                if "relay" in keys: current_state.setdefault("on", False)
                if "dimmer" in keys: current_state.setdefault("brightness", 0)
                if "temperature" in keys: current_state.setdefault("temperature", 0.0)
                if "humidity" in keys: current_state.setdefault("humidity", 0.0)
                if "motion" in keys: current_state.setdefault("motion", False)
                if "energy" in keys: current_state.setdefault("power", 0.0)
                    
                dev.state = current_state
                dev.status = "online"
                dev.save()
                
                if gateway.pairing_status in ("active", "success"):
                    was_active = (gateway.pairing_status == "active")
                    gateway.pairing_status = "success"
                    gateway.last_paired_device = {
                        "id": device_id,
                        "name": dev.name,
                        "type_name": dev.type_name,
                        "category": dev.category
                    }
                    if was_active:
                        try:
                            from hub.modules.communication.logic.notifier import PushNotifier
                            PushNotifier.notify_device_connected(dev)
                        except Exception:
                            pass
                    try:
                        from hub.modules.communication.logic.cloud_bridge import cloud_bridge
                        cloud_bridge._sync_devices()
                    except Exception:
                        pass
                
                return {"ok": True, "action": "discovered", "registry": reg_info}, 200

        elif cmd == 4: # CMD_HEARTBEAT
            payload = {}
            rssi = 0
            if dev and isinstance(dev.feature_keys, list):
                keys = dev.feature_keys
                # Light/Relay Heartbeat
                if "relay" in keys or "dimmer" in keys:
                    if len(raw_data) >= 2:
                        payload["on"] = (raw_data[0] != 0)
                        payload["brightness"] = raw_data[1]
                # Sensor Heartbeat (ejemplo de ProtocolExt.h)
                elif "temperature" in keys or "humidity" in keys:
                    if len(raw_data) >= 4:
                        temp_centi = (raw_data[0] << 8) | raw_data[1]
                        # Python handles signed 16-bit appropriately
                        if temp_centi > 32767: temp_centi -= 65536
                        hum_centi = (raw_data[2] << 8) | raw_data[3]
                        
                        payload["temperature"] = temp_centi / 100.0
                        payload["humidity"] = hum_centi / 100.0
            else:
                # Si no está descubierto, no podemos parsearlo de forma segura
                pass
        else:
            payload = {} 
            rssi = 0
    else:
        # Formato App / Bridge
        if "id" not in data:
            return {"error": "missing id"}, 400
        device_id = data["id"]
        rssi      = data.get("rssi", 0)
        payload   = data.get("payload", {})

    dev = Device.get(device_id)
    from hub.modules.communication.logic.gateway import gateway
    if not dev:
        # Si llega un paquete (que no es CMD_DISCOVER, ya que ese se procesó antes) de un nodo desconocido, no crear dispositivo.
        log = RFLog(
            ts=datetime.now().isoformat(),
            device_id=device_id,
            rssi=rssi if 'rssi' in locals() else 0,
            payload=payload,
            direction="RX"
        )
        log.save()
        return {"ok": True, "action": "ignored_unpaired"}, 200
    
    dev.update(payload, rssi if 'rssi' in locals() else 0)

    log = RFLog(
        ts=datetime.now().isoformat(),
        device_id=device_id,
        rssi=rssi if 'rssi' in locals() else 0,
        payload=payload,
        direction="RX"
    )
    log.save()

    # Disparar Motor de Automatización
    evaluator.evaluate_event(device_id, payload)

    return {"ok": True}, 200

@communication_bp.route("/ingest", methods=["POST"])
def api_ingest():
    data = request.get_json(silent=True)
    res, status = process_incoming_packet(data)
    return jsonify(res), status


@communication_bp.route("/command", methods=["POST"])
def api_command():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "bad request"}), 400

    device_id = data.get("id")
    dev = Device.get(device_id)
    if not dev and not str(device_id).startswith("dev_"):
        dev = Device.get(f"dev_{device_id}")
    if not dev and str(device_id).startswith("dev_"):
        dev = Device.get(str(device_id).split("_", 1)[1])
    if not dev:
        dev = Device(device_id=str(device_id), name=f"Device {device_id}", status="online")
        dev.save()

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

    try:
        from hub.modules.communication.logic.gateway import gateway
        if gateway.is_connected:
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
                gateway.send_command(dest_id=dest_id, command=0x10, device_type=getattr(dev, "device_type", 0) or 0, data=[ch1, ch2, ch3, ch4])
                if "on" in params and not any(k in params for k in ("ch1", "ch2", "ch3", "ch4")):
                    cmd_byte = 0x01 if params["on"] else 0x02
                    gateway.send_command(dest_id=dest_id, command=cmd_byte, device_type=getattr(dev, "device_type", 0) or 0, data=[ch1, ch2, ch3, ch4])
    except Exception as e:
        print(f"⚠️ [GATEWAY TX] Error en api_command: {e}")

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

@communication_bp.route("/pairing", methods=["POST"])
def api_pairing():
    data = request.get_json(silent=True) or {}
    action = data.get("action", "").lower()
    
    from hub.modules.communication.logic.gateway import gateway
    if not gateway.is_connected:
        return jsonify({"ok": False, "error": "Gateway no conectado"}), 400
        
    if action == "start":
        gateway.last_paired_device = None
        res = gateway.send_command(0x00, 0x0D)
        return jsonify({"ok": res, "mode": "pairing_started"})
    elif action == "stop":
        gateway.pairing_start_time = 0
        res = gateway.send_command(0x00, 0x0E)
        return jsonify({"ok": res, "mode": "pairing_stopped"})
    else:
        return jsonify({"ok": False, "error": "Accion invalida"}), 400

@communication_bp.route("/pairing/status", methods=["GET"])
def api_pairing_status():
    from hub.modules.communication.logic.gateway import gateway
    import time
    elapsed = int(time.time() - gateway.pairing_start_time) if gateway.pairing_start_time > 0 else 0
    return jsonify({
        "status": gateway.pairing_status,
        "last_tx": gateway.last_tx,
        "last_rx": gateway.last_rx,
        "elapsed": elapsed,
        "last_device": gateway.last_paired_device
    })

@communication_bp.route("/ports", methods=["GET"])
def api_ports():
    port_type = request.args.get("type", "COM")
    ports_list = []
    
    if port_type == "COM":
        try:
            ports = serial.tools.list_ports.comports()
            for p in ports:
                ports_list.append({
                    "id": p.device,
                    "label": f"{p.device} - {p.description}"
                })
        except Exception:
            pass
    elif port_type == "HID":
        try:
            import hid
            devices = hid.enumerate()
            for d in devices:
                # Filtrar dispositivos vacios o estandar
                prod = d.get('product_string', '')
                if not prod: continue
                
                vid = d.get('vendor_id', 0)
                pid = d.get('product_id', 0)
                path = d.get('path', b'').decode('utf-8', errors='ignore')
                
                ports_list.append({
                    "id": f"HID_{vid:04x}:{pid:04x}",
                    "label": f"[{vid:04x}:{pid:04x}] {prod} - {d.get('manufacturer_string', '')}"
                })
                
            if not ports_list:
                ports_list.append({
                    "id": "",
                    "label": "No se detectaron dispositivos HID USB"
                })
        except ImportError:
            ports_list.append({
                "id": "",
                "label": "Libreria 'hid' no instalada. Instala con pip install hidapi"
            })
        except Exception as e:
            ports_list.append({
                "id": "",
                "label": f"Error HID: {str(e)}"
            })
        
    return jsonify(ports_list)

@communication_bp.route("/settings", methods=["POST"])
def api_settings():
    data = request.get_json(silent=True)
    if not data or "rf_port" not in data:
        return jsonify({"error": "bad request"}), 400

    raw_port  = data["rf_port"]          # ej. "HID_1234:5678" o "COM3"
    port_type = data.get("port_type", "COM")

    # Normalizar formato: la UI envía HID_VVVV:PPPP, el gateway espera HID:VVVV:PPPP
    if port_type == "HID" and raw_port.startswith("HID_"):
        new_port = "HID:" + raw_port[4:]   # HID_1234:5678  →  HID:1234:5678
    else:
        new_port = raw_port

    from dotenv import set_key
    from hub.modules.communication.logic.gateway import gateway
    try:
        # 1. Persistir en .env
        if ENV_FILE.exists():
            set_key(str(ENV_FILE), "RF_PORT", new_port)
        else:
            with open(ENV_FILE, 'w', encoding='utf-8') as f:
                f.write(f"RF_PORT={new_port}\n")

        # 2. Actualizar os.environ para que getenv() lo refleje de inmediato
        import os
        os.environ["RF_PORT"] = new_port

        # 3. Reconectar el gateway en caliente sin reiniciar el servidor
        gateway.stop_listening()
        if gateway.hid_device:
            try: gateway.hid_device.close()
            except Exception: pass
            gateway.hid_device = None
        if gateway.serial_device:
            try: gateway.serial_device.close()
            except Exception: pass
            gateway.serial_device = None

        gateway.port_string  = new_port
        gateway.is_connected = False
        gateway.mode         = "NONE"

        if gateway.connect():
            from hub.modules.communication.routes.api import process_incoming_packet
            gateway.on_packet_received = process_incoming_packet
            gateway.start_listening()
            return jsonify({"ok": True, "connected": True, "port": new_port})
        else:
            return jsonify({"ok": True, "connected": False,
                            "warn": "Puerto guardado pero no se pudo conectar ahora.",
                            "port": new_port})

    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@communication_bp.route("/device-token/", methods=["POST", "PUT"])
@communication_bp.route("/device-token", methods=["POST", "PUT"])
def api_device_token():
    data = request.get_json(silent=True) or {}
    token = (data.get("token") or "").strip()
    if not token:
        return jsonify({"error": "token requerido"}), 400
    
    from hub.modules.communication.models.notification import DeviceToken
    dt = DeviceToken(token=token, platform=data.get("platform", "android"), updated_at=datetime.now().isoformat())
    dt.save()
    return jsonify({"ok": True, "message": "Token FCM registrado exitosamente en el Hub"})

@communication_bp.route("/notifications", methods=["GET"])
def api_get_notifications():
    from hub.modules.communication.models.notification import NotificationLog
    logs = [l.to_dict() for l in NotificationLog.all()]
    # Ordenar del más reciente al más antiguo
    logs.sort(key=lambda x: x.get("ts", ""), reverse=True)
    return jsonify(logs)

@communication_bp.route("/notifications", methods=["DELETE"])
def api_clear_notifications():
    from hub.db.database import Database
    Database.execute("DELETE FROM notification_logs")
    return jsonify({"ok": True, "message": "Historial de notificaciones limpiado"})

@communication_bp.route("/notifications/test", methods=["POST"])
def api_test_notification():
    data = request.get_json(silent=True) or {}
    title = data.get("title", "Prueba de Notificación")
    body = data.get("body", "El sistema de notificaciones push de la Colmena funciona correctamente.")
    from hub.modules.communication.logic.notifier import PushNotifier
    PushNotifier.send_notification(title=title, body=body, event_type="info")
    return jsonify({"ok": True, "message": "Notificación de prueba enviada"})

@communication_bp.route("/hub/pair", methods=["POST"])
def api_hub_pair():
    """
    Ruta llamada por la App Móvil para vincular este Hub a la cuenta del usuario en la Nube.
    Recibe el server_url y el user_token (JWT).
    El Hub hace la petición al servidor para registrarse y guarda las credenciales generadas.
    """
    data = request.get_json(silent=True) or {}
    server_url = data.get("server_url")
    user_token = data.get("user_token")
    name = data.get("name", "Mi Hogar Colmena")
    
    if not server_url or not user_token:
        return jsonify({"error": "server_url y user_token son requeridos"}), 400

    server_url = server_url.rstrip('/')
    
    # Intentar obtener la IP local del hub para enviarla al servidor
    local_ip = "127.0.0.1:5000"
    try:
        local_ip = request.host
    except:
        pass

    import requests
    try:
        # Registrar el hub en el servidor usando el token del usuario
        headers = {"Authorization": f"Bearer {user_token}", "Content-Type": "application/json"}
        payload = {"name": name, "local_url": f"http://{local_ip}"}
        
        r = requests.post(f"{server_url}/api/hubs", json=payload, headers=headers, timeout=10)
        
        if r.status_code == 201:
            res_data = r.json()
            hub_id = res_data.get("hub_id")
            relay_secret = res_data.get("relay_secret")
            
            if not hub_id or not relay_secret:
                return jsonify({"error": "Respuesta del servidor malformada"}), 502
            
            # Guardar en .env
            from dotenv import set_key
            import os
            
            if not ENV_FILE.exists():
                with open(ENV_FILE, 'w', encoding='utf-8') as f:
                    pass
            
            set_key(str(ENV_FILE), "CLOUD_SERVER_URL", server_url)
            set_key(str(ENV_FILE), "HUB_ID", hub_id)
            set_key(str(ENV_FILE), "HUB_RELAY_SECRET", relay_secret)
            
            # Actualizar memoria (para el bridge saliente)
            os.environ["CLOUD_SERVER_URL"] = server_url
            os.environ["HUB_ID"] = hub_id
            os.environ["HUB_RELAY_SECRET"] = relay_secret
            
            # Reiniciar cloud bridge (si estaba corriendo)
            from hub.modules.communication.logic.cloud_bridge import cloud_bridge
            cloud_bridge.stop()
            cloud_bridge.start()
            
            return jsonify({"ok": True, "hub_id": hub_id, "message": "Hub vinculado exitosamente"}), 200
        else:
            try:
                err_msg = r.json().get("error", "Error del servidor")
            except:
                err_msg = r.text
            return jsonify({"error": f"El servidor rechazó el registro: {err_msg}"}), r.status_code
            
    except requests.RequestException as e:
        return jsonify({"error": f"Error al conectar con el servidor en la nube: {str(e)}"}), 502

