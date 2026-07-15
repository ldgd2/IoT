from flask import Blueprint, jsonify, request
from datetime import datetime
import serial.tools.list_ports

from hub.core.config import ENV_FILE
from hub.modules.devices import Device, SmartDevice
from hub.modules.communication.models.rflog import RFLog
from hub.modules.automation.evaluator import evaluator
from hub.db.database import Database
from hub.core.device_types import DeviceRegistry

communication_bp = Blueprint('communication_api', __name__)

def process_incoming_packet(data):
    if not data:
        return {"error": "bad request"}, 400

    from hub.modules.communication.logic.gateway import gateway

    # Soporte para eventos de pairing del traductor ("event": "pairing_success")
    if data.get("event") == "pairing_success":
        node_id = data.get("nodeId") or data.get("origin")
        if node_id is not None:
            device_id = f"dev_{node_id}"
            device_name = data.get("name", f"Nodo {node_id}")
            device_type = data.get("type", 1) # Por defecto Luz/Relay (1)
            features = data.get("features", 1) # Por defecto relay

            dev = Device.get(device_id)
            if not dev:
                reg_info = DeviceRegistry.describe(device_type, features)
                ctrl = SmartDevice.recognize(
                    device_id=device_id,
                    type_code=reg_info["type_code"],
                    features=reg_info["features"],
                    name=device_name
                )
                dev = ctrl.orm_device if ctrl else Device.get(device_id)
                if dev:
                    current_state = dev.state if isinstance(dev.state, dict) else {}
                    if "relay" in reg_info["feature_keys"] or dev.category in ("switching", "light"):
                        current_state.setdefault("on", False)
                        current_state.setdefault("mask", 0)
                        for i in range(1, 17):
                            current_state.setdefault(f"ch{i}", False)
                    dev.state = current_state
                    dev.status = "online"
                    dev.save()

            if dev:
                dev.status = "online"
                dev.save()
                was_active = data.get("was_pairing_active", False) or (gateway.pairing_status in ("active", "success"))
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
                    except Exception as e:
                        print(f"[NOTIFIER] Error al notificar dispositivo connected: {e}")
                try:
                    from hub.modules.communication.logic.cloud_bridge import cloud_bridge
                    cloud_bridge._sync_devices()
                    cloud_bridge.send_event("device_paired", dev.to_dict())
                except Exception as e:
                    print(f"[CLOUD BRIDGE] Error en sync/send_event tras pairing_success: {e}")
        return {"ok": True, "action": "pairing_success_processed"}, 200

    # Soporte para paquetes RAW de RF24Mesh (origin, cmd, data)
    if "origin" in data and "cmd" in data:
        node_id = data["origin"]
        cmd = data["cmd"]
        raw_data = data.get("data", [])
        device_id = f"dev_{node_id}"
        
        dev = Device.get(device_id)
        
        if cmd == 5: # CMD_DISCOVER
            device_name = data.get("name", f"Nodo {node_id}")
            features = 1
            device_type = data.get("type", 1)

            if len(raw_data) >= 17:
                name_len = raw_data[0]
                name_chars = raw_data[1:1+name_len]
                parsed_name = "".join([chr(c) for c in name_chars if c != 0])
                if parsed_name.strip():
                    device_name = parsed_name.strip()
                features = raw_data[16]
            elif len(raw_data) > 1:
                name_len = raw_data[0]
                if name_len < len(raw_data):
                    name_chars = raw_data[1:1+name_len]
                    parsed_name = "".join([chr(c) for c in name_chars if c != 0])
                    if parsed_name.strip():
                        device_name = parsed_name.strip()

            reg_info = DeviceRegistry.describe(device_type, features)
            
            if not dev:
                if gateway.pairing_status not in ("active", "success"):
                    log = RFLog(
                        ts=datetime.now().isoformat(),
                        device_id=device_id,
                        rssi=0,
                        payload={"warn": "ignored_discover_not_pairing"},
                        direction="RX"
                    )
                    log.save()
                    return {"ok": True, "action": "ignored_not_pairing"}, 200

            ctrl = SmartDevice.recognize(
                device_id=device_id,
                type_code=reg_info["type_code"],
                features=reg_info["features"],
                name=device_name
            )
            dev = ctrl.orm_device if ctrl else Device.get(device_id)
            if dev:
                current_state = dev.state if isinstance(dev.state, dict) else {}
                keys = reg_info["feature_keys"]
                if "relay" in keys or dev.category in ("switching", "light"):
                    current_state.setdefault("on", False)
                    current_state.setdefault("mask", 0)
                    for i in range(1, 17):
                        current_state.setdefault(f"ch{i}", False)
                if "dimmer" in keys: current_state.setdefault("brightness", 0)
                if "temperature" in keys: current_state.setdefault("temperature", 0.0)
                if "humidity" in keys: current_state.setdefault("humidity", 0.0)
                if "motion" in keys: current_state.setdefault("motion", False)
                if "energy" in keys: current_state.setdefault("power", 0.0)
                dev.state = current_state
                dev.status = "online"
                dev.save()
            
            if gateway.pairing_status in ("active", "success") and dev:
                was_active = data.get("was_pairing_active", False) or (gateway.pairing_status in ("active", "success"))
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
                    except Exception as e:
                        print(f"[NOTIFIER] Error al notificar dispositivo connected: {e}")
                try:
                    from hub.modules.communication.logic.cloud_bridge import cloud_bridge
                    cloud_bridge._sync_devices()
                    cloud_bridge.send_event("device_paired", dev.to_dict())
                except Exception as e:
                    print(f"[CLOUD BRIDGE] Error en sync/send_event tras CMD_DISCOVER: {e}")
                
                return {"ok": True, "action": "discovered", "registry": reg_info}, 200

        elif cmd in (2, 3, 4): # CMD_REPORT, CMD_SYNC, CMD_HEARTBEAT
            payload = {}
            rssi = 0
            if dev and dev.controller:
                payload = dev.controller.decode_rx(cmd, raw_data)
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
        if gateway.pairing_status in ("active", "success") or data.get("was_pairing_active"):
            device_type = data.get("type", 1)
            features = data.get("features", 1)
            ctrl = SmartDevice.recognize(device_id, type_code=device_type, features=features)
            dev = ctrl.orm_device if ctrl else Device.get(device_id)
            if dev:
                current_state = dev.state if isinstance(dev.state, dict) else {}
                if ctrl and (isinstance(ctrl, LightDevice) or "relay" in dev.feature_keys or dev.category in ("switching", "light")):
                    current_state.setdefault("on", False)
                    current_state.setdefault("mask", 0)
                    for i in range(1, 17):
                        current_state.setdefault(f"ch{i}", False)
                dev.state = current_state
                dev.status = "online"
                dev.save()
            try:
                from hub.modules.automation.routes.push import PushNotifier
                PushNotifier.notify_device_connected(dev)
            except Exception:
                pass
            try:
                from hub.modules.communication.logic.cloud_bridge import cloud_bridge
                cloud_bridge._sync_devices()
                cloud_bridge.send_event("device_paired", dev.to_dict())
            except Exception as e:
                print(f"[CLOUD BRIDGE] Error en sync/send_event tras auto-pair: {e}")
        else:
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

    ctrl = dev.controller
    if ctrl:
        ctrl.execute_command(params)
    else:
        if isinstance(dev.state, dict):
            dev.state.update(params)
        dev.update(dev.state if isinstance(dev.state, dict) else params)

    log = RFLog(
        ts=datetime.now().isoformat(),
        device_id=device_id,
        direction="TX",
        cmd=cmd,
        payload=params
    )
    log.save()

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

@communication_bp.route("/device-token/", methods=["POST", "PUT", "DELETE"])
@communication_bp.route("/device-token", methods=["POST", "PUT", "DELETE"])
def api_device_token():
    data = request.get_json(silent=True) or {}
    token = (data.get("token") or "").strip()
    if not token:
        return jsonify({"error": "token requerido"}), 400
    
    if request.method == "DELETE":
        from hub.db.database import Database
        Database.execute("DELETE FROM device_tokens WHERE token = ?", (token,))
        return jsonify({"ok": True, "message": "Token eliminado del Hub local exitosamente"})

    user_id = (data.get("user_id") or "").strip()
    device_name = data.get("device_name", "Android Device")
    from hub.modules.communication.models.notification import DeviceToken
    dt = DeviceToken(token=token, user_id=user_id, platform=data.get("platform", "android"), device_name=device_name, updated_at=datetime.now().isoformat())
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
    if server_url.endswith('/api'):
        server_url = server_url[:-4]
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
        payload = {
            "name": name,
            "local_url": f"http://{local_ip}",
            "hub_id": os.environ.get("HUB_ID", "")
        }
        
        r = requests.post(f"{server_url}/api/hubs", json=payload, headers=headers, timeout=10)
        
        if r.status_code in [200, 201]:
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

