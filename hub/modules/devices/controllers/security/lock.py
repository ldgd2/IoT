from typing import Dict, Any, List, Tuple
from hub.modules.devices.controllers.base import BaseDeviceController

class SecurityDevice(BaseDeviceController):
    """
    Controlador especializado para Seguridad y Control de Acceso:
    - Cerraduras Inteligentes (0x30)
    - Sirenas y Alarma (0x32)
    - Teclados de Acceso (0x33)
    """

    def can_receive(self) -> List[Dict[str, Any]]:
        if self.type_code == 0x30 or "lock" in (self.name or "").lower():
            return [{
                "key": "locked",
                "label": "Estado de Bloqueo (Locked / Unlocked)",
                "type": "Booleano (True=Bloqueado, False=Abierto)",
                "control": "switch",
                "desc": "Cerrar o abrir el cerrojo electrónico.",
                "default": True
            }]
        return [{
            "key": "on",
            "label": "Activar Sirena / Alarma",
            "type": "Booleano",
            "control": "switch",
            "desc": "Encender o silenciar sirena de alarma.",
            "default": False
        }]

    def can_send(self) -> List[Dict[str, Any]]:
        if self.type_code == 0x30:
            return [{"key": "locked", "unit": "", "label": "Estado Cerradura", "desc": "Indica si está cerrado."}]
        return [{"key": "on", "unit": "", "label": "Estado Sirena", "desc": "Indica si está sonando."}]

    def decode_rx(self, cmd: int, raw_data: List[int]) -> Dict[str, Any]:
        payload = {}
        if not raw_data:
            return payload

        if self.type_code == 0x30:
            payload["locked"] = (raw_data[0] != 0)
        else:
            payload["on"] = (raw_data[0] != 0)

        return payload

    def encode_tx(self, params: Dict[str, Any]) -> Tuple[int, List[int]]:
        data = [0] * 26
        if self.type_code == 0x30:
            val = params.get("locked", self.state.get("locked", True))
            data[0] = 1 if val else 0
            cmd = 0x01 if val else 0x02
        else:
            val = params.get("on", self.state.get("on", False))
            data[0] = 1 if val else 0
            cmd = 0x01 if val else 0x02
        return (cmd, data)
