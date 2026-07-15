from typing import Dict, Any, List, Tuple
from hub.modules.devices.controllers.base import BaseDeviceController

class LightDevice(BaseDeviceController):
    """
    Controlador especializado para Dispositivos de Iluminación y Conmutación:
    - Luces simples y dimmers PWM (0x02, 0x04, 0x09)
    - Enchufes e interruptores multicanal inteligentes (0x01, 0x03, 0x05, 0x07, 0x08)
    
    Gestiona de forma nativa la máscara bitwise (mask) de N canales y el nivel
    de intensidad (brightness) de manera autogestionable.
    """

    def can_receive(self) -> List[Dict[str, Any]]:
        params = []
        # Todos los dispositivos switching aceptan comando general ON/OFF
        params.append({
            "key": "on",
            "label": "Estado / Encendido (ON / OFF)",
            "type": "Booleano (True / False)",
            "control": "switch",
            "desc": "Control de encendido y apagado general.",
            "default": False
        })
        
        # Si tiene soporte para control de brillo (dimmer)
        if "dimmer" in self.feature_keys or self.type_code in (0x02, 0x04, 0x09):
            params.append({
                "key": "brightness",
                "label": "Intensidad de Brillo",
                "type": "Entero (0 - 255)",
                "control": "slider",
                "desc": "Ajuste de intensidad luminosa (0 a 100%).",
                "default": 255
            })
            
        # Si tiene relés/switches, informar la capacidad multicanal y cada switch individual
        if "relay" in self.feature_keys or self.category in ("switching", "light"):
            params.append({
                "key": "mask",
                "label": "Máscara Bitwise de Relés (RelayMask)",
                "type": "Entero Bitwise 32-bit",
                "control": "mask",
                "desc": "Control autogestionado multicanal donde cada bit representa el estado lógico de un switch (bit 0 = ch1, bit 1 = ch2...).",
                "default": 0
            })
            for i in range(1, 9):
                k = f"ch{i}"
                if k in self.state or i <= 4 or "relay" in self.feature_keys:
                    params.append({
                        "key": k,
                        "label": f"Canal {i}",
                        "type": "Booleano (True / False)",
                        "control": "switch",
                        "desc": f"Control individual independiente para el relé/canal {i}.",
                        "default": False
                    })
            
        return params

    def can_send(self) -> List[Dict[str, Any]]:
        params = [
            {"key": "on", "unit": "", "label": "Estado General ON/OFF", "desc": "Indica si algún relé/luz está encendido."},
            {"key": "mask", "unit": "hex", "label": "Máscara de Canales Activos", "desc": "Estado de cada canal individual en formato bitwise."}
        ]
        if "dimmer" in self.feature_keys or self.type_code in (0x02, 0x04, 0x09):
            params.append({"key": "brightness", "unit": "PWM", "label": "Nivel de Brillo", "desc": "Valor reportado de brillo (0-255)."})
        if "relay" in self.feature_keys or self.category in ("switching", "light"):
            for i in range(1, 9):
                k = f"ch{i}"
                if k in self.state or i <= 4 or "relay" in self.feature_keys:
                    params.append({
                        "key": k, "unit": "", "label": f"Canal {i}", "desc": f"Estado reportado del relé individual {i}."
                    })
        return params

    def decode_rx(self, cmd: int, raw_data: List[int]) -> Dict[str, Any]:
        """
        Decodifica paquetes entrantes (CMD_HEARTBEAT=4, CMD_REPORT=2, CMD_SYNC=3)
        extrayendo la máscara de relés de hasta 32 bits y el nivel de brillo.
        """
        payload = {}
        if not raw_data:
            return payload

        # Formato estándar ColmenaNode:
        # raw_data[0] = estado ch1 / general (0 o 1)
        # raw_data[1] = brillo (0 - 255)
        # raw_data[2..5] = máscara de relés (hasta 32 canales en 4 bytes Little Endian)
        if len(raw_data) >= 2:
            payload["on"] = (raw_data[0] != 0)
            payload["brightness"] = raw_data[1]

        if len(raw_data) >= 4:
            b2 = raw_data[2]
            b3 = raw_data[3]
            b4 = raw_data[4] if len(raw_data) >= 5 else 0
            b5 = raw_data[5] if len(raw_data) >= 6 else 0
            relay_mask = b2 | (b3 << 8) | (b4 << 16) | (b5 << 24)
            payload["mask"] = relay_mask
            
            # Desplegar los canales en el payload para sincronización instantánea
            for i in range(16):
                payload[f"ch{i+1}"] = bool(relay_mask & (1 << i))
            payload["on"] = bool(relay_mask != 0)

        return payload

    def encode_tx(self, params: Dict[str, Any]) -> Tuple[int, List[int]]:
        """
        Convierte la orden en un paquete de control (CMD_CONTROL=0x10 o CMD_ON/OFF)
        empacando los 4 bytes del bitmask más los estados individuales.
        """
        mask = params.get("mask", self.state.get("mask", 0))
        if not isinstance(mask, int):
            mask = int(mask) if str(mask).isdigit() else 0

        # Sincronizar mask si recibimos llaves específicas 'chX'
        all_keys = set(self.state.keys()) | set(params.keys())
        for k in all_keys:
            if k.startswith("ch") and k[2:].isdigit():
                ch_num = int(k[2:])
                if ch_num >= 1:
                    val = params.get(k, self.state.get(k, False))
                    if val:
                        mask |= (1 << (ch_num - 1))
                    else:
                        mask &= ~(1 << (ch_num - 1))

        # Si se comanda 'on' sin canales o máscara específica
        if "on" in params and not any(k.startswith("ch") and k[2:].isdigit() for k in params.keys()):
            if params["on"]:
                mask = 1 if mask == 0 else mask | 1
            else:
                mask = 0

        # Array de 26 bytes: primeros 4 bytes son el mask 32-bit (Little-Endian)
        data_payload = [
            mask & 0xFF,
            (mask >> 8) & 0xFF,
            (mask >> 16) & 0xFF,
            (mask >> 24) & 0xFF
        ]
        # Siguientes 22 bytes para switches individuales si el firmware los consulta por índice
        for i in range(22):
            data_payload.append(1 if (mask & (1 << i)) else 0)

        # Si se ajusta el brillo explícitamente en un dimmer, se puede mandar también al byte 1 o vía CMD_CONTROL
        if "brightness" in params:
            try:
                data_payload[1] = int(params["brightness"]) & 0xFF
            except Exception:
                pass

        # Mandar siempre CMD_CONTROL (0x10) con el bitmask exacto para que el nodo aplique el estado exacto de cada canal
        return (0x10, data_payload)
