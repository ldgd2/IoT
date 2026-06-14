import threading
import time
import json
import logging
from datetime import datetime
from server.modules.devices.models.device import Device
from server.modules.automation.models.skill import Skill

logger = logging.getLogger("AST_Evaluator")

class EvaluatorEngine:
    """
    Motor PseInt / AST para el entorno IoT.
    Evalúa las condiciones y ejecuta las acciones.
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
        Evalúa automatizaciones periódicamente (cada 60 segundos).
        Ideal para triggers de tiempo o clima.
        """
        while self.running:
            self.evaluate_all(trigger_source="tick")
            time.sleep(60)

    def evaluate_event(self, device_id: str, new_state: dict):
        """
        Se llama INMEDIATAMENTE cuando llega un paquete de un sensor.
        Rendimiento en tiempo real.
        """
        self.evaluate_all(trigger_source="event", event_data={"device_id": device_id, "state": new_state})

    def evaluate_all(self, trigger_source="tick", event_data=None):
        """
        Itera todas las Skills activas en la BD y evalúa su AST.
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
                    
            if not ast or "conditions" not in ast:
                continue

            # 1. Evaluar si todas las condiciones se cumplen (AND)
            # En un futuro podríamos soportar OR
            all_met = True
            for cond in ast.get("conditions", []):
                if not self._eval_condition(cond, trigger_source, event_data):
                    all_met = False
                    break
            
            # 2. Si se cumplen, disparar acciones
            if all_met and len(ast.get("conditions", [])) > 0:
                logger.info(f"🚀 Skill disparada: {skill.name}")
                self._execute_actions(ast.get("actions", []))

    def _eval_condition(self, cond: dict, source: str, event_data: dict = None) -> bool:
        ctype = cond.get("type")
        
        # --- TIEMPO ---
        if ctype == "time":
            # Formato esperado: "HH:MM"
            target_time = cond.get("time", "")
            now = datetime.now().strftime("%H:%M")
            return target_time == now

        # --- EVENTOS DISPOSITIVO ---
        if ctype in ["device_state", "dev_sensor", "dev_motion", "dev_plug"]:
            dev_id = cond.get("device")
            operator = cond.get("operator", "==")
            target_val = cond.get("val")
            
            # Obtener estado actual (ya sea del evento o de la DB)
            current_val = None
            if source == "event" and event_data and event_data["device_id"] == dev_id:
                state = event_data["state"]
                # Simplificamos: Asumimos que el sensor reporta un valor principal (ej: state["value"])
                # o iteramos para encontrar el valor.
                current_val = next(iter(state.values())) if state else None
            else:
                dev = Device.get(dev_id)
                if dev and isinstance(dev.state, dict) and dev.state:
                    current_val = next(iter(dev.state.values()))
            
            if current_val is None:
                return False
                
            # Operaciones
            try:
                cv = float(current_val)
                tv = float(target_val)
                if operator == "==": return cv == tv
                if operator == ">": return cv > tv
                if operator == "<": return cv < tv
            except ValueError:
                # Fallback a string
                if operator == "==": return str(current_val).lower() == str(target_val).lower()
                
            return False
            
        # --- BOTON FISICO ---
        if ctype == "dev_button":
            if source != "event" or not event_data:
                return False
            if event_data["device_id"] != cond.get("device"):
                return False
            
            # state = {"action": "single_click"}
            state = event_data["state"]
            return state.get("action") == cond.get("action")

        return False

    def _execute_actions(self, actions: list):
        for act in actions:
            atype = act.get("type")
            dev_id = act.get("device")
            
            if atype in ["action_device", "action_light", "action_plug"]:
                cmd = act.get("cmd", "TOGGLE")
                logger.info(f"-> Mandando {cmd} a {dev_id} via RF")
                # Aquí llamaríamos a RFGateway.send(dev_id, cmd)
                
            elif atype == "action_dimmer":
                bright = act.get("brightness", 100)
                logger.info(f"-> Mandando Brillo={bright}% a {dev_id}")
                
            elif atype == "action_color":
                color = act.get("color", "#FFFFFF")
                logger.info(f"-> Mandando Color={color} a {dev_id}")
                
            elif atype == "action_notify":
                msg = act.get("message", "")
                logger.info(f"-> NOTIFICACIÓN PUSH: {msg}")
                # Llamar a API de Telegram o Pushbullet

# Instancia Global
evaluator = EvaluatorEngine()
