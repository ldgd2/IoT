from typing import Dict, Any, List, Tuple
from hub.modules.devices.controllers.base import BaseDeviceController

class HvacDevice(BaseDeviceController):
    """
    Controlador especializado para Climatización y HVAC:
    - Termostatos inteligentes (0x20)
    - Aire Acondicionado (0x21)
    - Calefactores y Humidificadores (0x22, 0x23)
    """

    def can_receive(self) -> List[Dict[str, Any]]:
        return [
            {
                "key": "on",
                "label": "Estado Climatizador (ON / OFF)",
                "type": "Booleano",
                "control": "switch",
                "desc": "Encender o apagar el sistema de climatización.",
                "default": False
            },
            {
                "key": "target_temp",
                "label": "Temperatura Consigna (°C)",
                "type": "Decimal (°C)",
                "control": "number",
                "desc": "Temperatura objetivo para el control automático del climatizador.",
                "default": 22.0
            },
            {
                "key": "mode",
                "label": "Modo Operativo HVAC",
                "type": "Texto ('cool' | 'heat' | 'auto' | 'off')",
                "control": "select",
                "desc": "Modo de funcionamiento del climatizador.",
                "default": "auto"
            }
        ]

    def can_send(self) -> List[Dict[str, Any]]:
        return [
            {"key": "on", "unit": "", "label": "Estado ON/OFF", "desc": "Estado actual de encendido."},
            {"key": "target_temp", "unit": "°C", "label": "Consigna Actual", "desc": "Temperatura programada."},
            {"key": "mode", "unit": "", "label": "Modo Actual", "desc": "Modo operativo en curso."},
            {"key": "current_temp", "unit": "°C", "label": "Temperatura Ambiente medido por Termostato", "desc": "Temperatura local medida."}
        ]

    def decode_rx(self, cmd: int, raw_data: List[int]) -> Dict[str, Any]:
        payload = {}
        if not raw_data:
            return payload

        if len(raw_data) >= 1:
            payload["on"] = (raw_data[0] != 0)
        if len(raw_data) >= 3:
            temp_centi = (raw_data[1] << 8) | raw_data[2]
            if temp_centi > 32767:
                temp_centi -= 65536
            payload["target_temp"] = round(temp_centi / 100.0, 2)
        if len(raw_data) >= 4:
            modes = {0: "off", 1: "cool", 2: "heat", 3: "auto"}
            payload["mode"] = modes.get(raw_data[3], "auto")
            
        return payload

    def encode_tx(self, params: Dict[str, Any]) -> Tuple[int, List[int]]:
        data = [0] * 26
        data[0] = 1 if params.get("on", self.state.get("on", False)) else 0
        
        target = params.get("target_temp", self.state.get("target_temp", 22.0))
        try:
            temp_centi = int(float(target) * 100)
            data[1] = (temp_centi >> 8) & 0xFF
            data[2] = temp_centi & 0xFF
        except Exception:
            pass

        mode_str = params.get("mode", self.state.get("mode", "auto"))
        modes_map = {"off": 0, "cool": 1, "heat": 2, "auto": 3}
        data[3] = modes_map.get(mode_str, 3)

        return (0x10, data)
