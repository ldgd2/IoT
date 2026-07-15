import threading
import time
import json
import logging
from datetime import datetime
from hub.modules.devices.models.device import Device
from hub.modules.automation.models.skill import Skill

logger = logging.getLogger("AST_Evaluator")

class EvaluatorEngine:
    """
    Motor PseInt / AST para el entorno IoT.
    Evalua las condiciones y ejecuta las acciones de forma modular e intuitiva.
    """
    def __init__(self):
        self.running = False
        self.thread = None

    def start(self):
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self._tick_loop, daemon=True)
            self.thread.start()
            logger.info("Evaluador AST iniciado.")

    def stop(self):
        self.running = False

    def _tick_loop(self):
        """
        Evalua automatizaciones periodicamente (cada 60 segundos).
        Ideal para triggers de tiempo o clima.
        """
        while self.running:
            try:
                self.evaluate_all(trigger_source="tick")
            except Exception as e:
                logger.error(f"Error en tick_loop de Evaluator: {e}")
            time.sleep(60)

    def evaluate_event(self, device_id: str, new_state: dict):
        """
        Se llama INMEDIATAMENTE cuando llega un paquete de un sensor.
        Rendimiento en tiempo real.
        """
        try:
            self.evaluate_all(trigger_source="event", event_data={"device_id": device_id, "state": new_state})
        except Exception as e:
            logger.error(f"Error al evaluar evento en Evaluator: {e}")

    def evaluate_all(self, trigger_source="tick", event_data=None):
        """
        Itera todas las Skills activas en la BD y evalua su AST.
        """
        skills = Skill.all()
        for skill in skills:
            if not getattr(skill, "is_active", 1):
                continue
            
            ast = getattr(skill, "ast_json", {})
            if isinstance(ast, str):
                try:
                    ast = json.loads(ast)
                except Exception:
                    continue
                    
            if not ast or not isinstance(ast, dict) or "conditions" not in ast:
                continue

            conditions = ast.get("conditions", [])
            if not conditions:
                continue

            # 1. Evaluar si todas las condiciones se cumplen (AND)
            all_met = True
            for cond in conditions:
                if not isinstance(cond, dict):
                    all_met = False
                    break
                if not self._eval_condition(cond, trigger_source, event_data):
                    all_met = False
                    break
            
            # 2. Si se cumplen, disparar acciones
            if all_met:
                logger.info(f"[SKILL DISPARADA] Ejecutando Skill: {skill.name}")
                actions = ast.get("actions", [])
                if isinstance(actions, list):
                    self._execute_actions(actions)

    def _eval_condition(self, cond: dict, source: str, event_data: dict = None) -> bool:
        ctype = cond.get("type")
        # Soporta tanto propiedades planas (cond["device"]) como anidadas (cond["config"]["device"])
        cfg = cond.get("config", {}) if isinstance(cond.get("config"), dict) else {}
        
        # --- TIEMPO ---
        if ctype == "time":
            target_time = cond.get("time") or cfg.get("time", "")
            if not target_time:
                return False
            now = datetime.now().strftime("%H:%M")
            return target_time == now

        # --- EVENTOS DISPOSITIVO / SENSOR ---
        if ctype in ["device_state", "dev_sensor", "dev_motion", "dev_plug"]:
            dev_id = cond.get("device") or cfg.get("device")
            operator = cond.get("operator") or cfg.get("operator", "==")
            target_val = cond.get("val") if "val" in cond else cfg.get("val")
            
            if not dev_id or target_val is None:
                return False

            # Obtener estado actual (del evento o de la DB)
            current_val = None
            if source == "event" and event_data and event_data["device_id"] == dev_id:
                state = event_data.get("state", {})
                if isinstance(state, dict):
                    if "temperature" in state and ctype == "dev_sensor":
                        current_val = state.get("temperature")
                    elif "on" in state and str(target_val).upper() in ["ON", "OFF", "TRUE", "FALSE", "1", "0"]:
                        current_val = state.get("on")
                    elif "motion" in state and ctype == "dev_motion":
                        current_val = state.get("motion")
                    elif "power" in state and ctype == "dev_plug":
                        current_val = state.get("power")
                    else:
                        current_val = next(iter(state.values())) if state else None
            else:
                dev = Device.get(dev_id)
                if dev and isinstance(dev.state, dict) and dev.state:
                    if "temperature" in dev.state and ctype == "dev_sensor":
                        current_val = dev.state.get("temperature")
                    elif "on" in dev.state and str(target_val).upper() in ["ON", "OFF", "TRUE", "FALSE", "1", "0"]:
                        current_val = dev.state.get("on")
                    elif "motion" in dev.state and ctype == "dev_motion":
                        current_val = dev.state.get("motion")
                    elif "power" in dev.state and ctype == "dev_plug":
                        current_val = dev.state.get("power")
                    else:
                        current_val = next(iter(dev.state.values()))
            
            if current_val is None:
                return False
                
            # Mapeo booleano
            if isinstance(current_val, bool):
                current_val = "ON" if current_val else "OFF"
            if str(target_val).upper() in ["TRUE", "1", "ON"]:
                target_val = "ON"
            elif str(target_val).upper() in ["FALSE", "0", "OFF"]:
                target_val = "OFF"

            # Operaciones aritmeticas / comparativas
            try:
                cv = float(current_val)
                tv = float(target_val)
                if operator == "==": return cv == tv
                if operator == ">": return cv > tv
                if operator == "<": return cv < tv
                if operator == "!=": return cv != tv
                if operator == ">=": return cv >= tv
                if operator == "<=": return cv <= tv
            except ValueError:
                if operator == "==": return str(current_val).lower() == str(target_val).lower()
                if operator == "!=": return str(current_val).lower() != str(target_val).lower()
                
            return False
            
        # --- BOTON FISICO ---
        if ctype == "dev_button":
            dev_id = cond.get("device") or cfg.get("device")
            target_action = cond.get("action") or cfg.get("action")
            if source != "event" or not event_data or not dev_id:
                return False
            if event_data["device_id"] != dev_id:
                return False
            
            state = event_data.get("state", {})
            return isinstance(state, dict) and state.get("action") == target_action

        return False

    def _execute_actions(self, actions: list):
        from hub.modules.communication.logic.gateway import gateway

        for act in actions:
            if not isinstance(act, dict):
                continue
            atype = act.get("type")
            cfg = act.get("config", {}) if isinstance(act.get("config"), dict) else {}
            
            dev_id = act.get("device") or cfg.get("device")
            
            node_id = 0
            if dev_id and dev_id.startswith("dev_"):
                try:
                    node_id = int(dev_id.split("_")[1])
                except Exception:
                    pass

            if atype in ["action_device", "action_light", "action_plug"]:
                cmd_str = act.get("cmd") or cfg.get("cmd", "TOGGLE")
                logger.info(f"-> Mandando {cmd_str} a {dev_id} via RF (Nodo {node_id})")
                
                cmd_map = {
                    "ON": 0x01,
                    "OFF": 0x02,
                    "TOGGLE": 0x03
                }
                cmd_byte = cmd_map.get(str(cmd_str).upper(), 0x01)
                
                gateway.send_command(dest_id=node_id, command=cmd_byte)
                
                dev = Device.get(dev_id)
                if dev:
                    if not isinstance(dev.state, dict):
                        dev.state = {}
                    if str(cmd_str).upper() == "ON":
                        dev.state["on"] = True
                    elif str(cmd_str).upper() == "OFF":
                        dev.state["on"] = False
                    elif str(cmd_str).upper() == "TOGGLE":
                        dev.state["on"] = not dev.state.get("on", False)
                    dev.update(dev.state)
                
            elif atype == "action_dimmer":
                bright = act.get("brightness") if "brightness" in act else cfg.get("brightness", 100)
                logger.info(f"-> Mandando Brillo={bright}% a {dev_id}")
                dev = Device.get(dev_id)
                if dev:
                    if not isinstance(dev.state, dict): dev.state = {}
                    dev.state["brightness"] = int(bright)
                    dev.state["on"] = int(bright) > 0
                    dev.update(dev.state)
                
            elif atype == "action_color":
                color = act.get("color") or cfg.get("color", "#FFFFFF")
                bright = act.get("brightness") if "brightness" in act else cfg.get("brightness", 100)
                logger.info(f"-> Mandando Color={color}, Brillo={bright}% a {dev_id}")
                dev = Device.get(dev_id)
                if dev:
                    if not isinstance(dev.state, dict): dev.state = {}
                    dev.state["color"] = color
                    dev.state["brightness"] = int(bright)
                    dev.state["on"] = int(bright) > 0
                    dev.update(dev.state)
                
            elif atype == "action_buzzer":
                seconds = act.get("seconds") if "seconds" in act else cfg.get("seconds", 3)
                logger.info(f"-> Mandando Buzzer por {seconds}s a {dev_id}")
                gateway.send_command(dest_id=node_id, command=0x01)
                
            elif atype == "action_notify":
                msg = act.get("message") or cfg.get("message", "Notificacion de Skill IoT")
                title = act.get("title") or cfg.get("title") or "Alerta IoT Colmena"
                priority = act.get("priority") or cfg.get("priority", "high")
                logger.info(f"-> NOTIFICACION PUSH: {title} - {msg}")
                try:
                    from hub.modules.communication.logic.notifier import PushNotifier
                    PushNotifier.notify_skill_action(skill_name=title, message=msg, priority=priority, extra={"type": "SKILL", "action": "notify"})
                except Exception as e:
                    logger.error(f"Error despachando action_notify: {e}")
                
            elif atype == "action_delay":
                delay_val = act.get("delay") if "delay" in act else cfg.get("delay", 5)
                unit = act.get("unit") or cfg.get("unit", "seg")
                secs = float(delay_val) * (60 if unit == "min" else 1)
                logger.info(f"-> Pausa AST por {secs}s...")
                time.sleep(secs)

# Instancia Global
evaluator = EvaluatorEngine()
