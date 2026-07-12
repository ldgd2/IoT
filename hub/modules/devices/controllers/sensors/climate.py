from typing import Dict, Any, List, Tuple
from hub.modules.devices.controllers.base import BaseDeviceController

class SensorDevice(BaseDeviceController):
    """
    Controlador especializado para Sensores y Telemetría de la Colmena:
    - Sensores ambientales de temperatura y humedad (0x11, FEAT_TEMP | FEAT_HUMIDITY)
    - Detectores de movimiento PIR y presencia (0x12, FEAT_MOTION)
    - Medidores de energía y potencia eléctrica (0x19, FEAT_ENERGY)
    - Sensores de puerta, gas, humo, inundación y luz ambiental
    """

    def can_receive(self) -> List[Dict[str, Any]]:
        # La mayoría de sensores son de solo lectura, salvo que tengan un relé o zumbador integrado
        params = []
        if "relay" in self.feature_keys:
            params.append({
                "key": "on",
                "label": "Estado Relé / Alarma (ON / OFF)",
                "type": "Booleano",
                "control": "switch",
                "desc": "Activar o desactivar relé/zumbador interno del sensor.",
                "default": False
            })
        return params

    def can_send(self) -> List[Dict[str, Any]]:
        params = []
        keys = self.feature_keys
        name_lower = (self.name or "").lower()

        if "temperature" in keys or self.type_code == 0x11 or any(kw in name_lower for kw in ["temp", "temperatura", "clima"]):
            params.append({"key": "temperature", "unit": "°C", "label": "Sensor de Temperatura", "desc": "Medición térmica en tiempo real."})
        if "humidity" in keys or any(kw in name_lower for kw in ["humedad", "higrometro", "humidity"]):
            params.append({"key": "humidity", "unit": "%", "label": "Sensor de Humedad", "desc": "Humedad relativa del aire."})
        if "motion" in keys or self.type_code == 0x12 or any(kw in name_lower for kw in ["movimiento", "pir", "presencia"]):
            params.append({"key": "motion", "unit": "PIR", "label": "Detector de Movimiento", "desc": "Presencia detectada."})
        if "energy" in keys or self.type_code == 0x19 or any(kw in name_lower for kw in ["consumo", "medidor", "potencia", "power"]):
            params.append({"key": "power", "unit": "W", "label": "Potencia Activa", "desc": "Consumo en Watts en tiempo real."})
            params.append({"key": "voltage", "unit": "V", "label": "Voltaje de Red", "desc": "Tensión en Voltios."})
        if "battery" in keys:
            params.append({"key": "battery", "unit": "%", "label": "Nivel de Batería", "desc": "Porcentaje de batería."})

        return params

    def decode_rx(self, cmd: int, raw_data: List[int]) -> Dict[str, Any]:
        payload = {}
        if not raw_data:
            return payload

        keys = self.feature_keys
        # Si es un sensor de temperatura + humedad según protocolo binario Colmena (ProtocolExt.h)
        if "temperature" in keys or "humidity" in keys or self.type_code == 0x11:
            if len(raw_data) >= 4:
                temp_centi = (raw_data[0] << 8) | raw_data[1]
                if temp_centi > 32767:
                    temp_centi -= 65536
                hum_centi = (raw_data[2] << 8) | raw_data[3]
                
                payload["temperature"] = round(temp_centi / 100.0, 2)
                payload["humidity"] = round(hum_centi / 100.0, 2)

        # Si es medidor de energía
        if "energy" in keys or self.type_code == 0x19:
            if len(raw_data) >= 6:
                power_w = (raw_data[0] << 8) | raw_data[1]
                voltage_v = (raw_data[2] << 8) | raw_data[3]
                payload["power"] = power_w
                payload["voltage"] = voltage_v

        # Si incluye byte de batería (por convención al final de raw_data si tiene FEAT_BATTERY)
        if "battery" in keys and len(raw_data) >= 5:
            payload["battery"] = raw_data[-1]

        return payload

    def encode_tx(self, params: Dict[str, Any]) -> Tuple[int, List[int]]:
        # Si tiene un relé/zumbador interno
        if "on" in params:
            cmd_byte = 0x01 if params["on"] else 0x02
            return (cmd_byte, [1 if params["on"] else 0] * 26)
        return (0x10, [0] * 26)
