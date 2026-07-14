from typing import Optional, Dict, Any, Union
from hub.modules.devices.models.device import Device
from hub.modules.devices.controllers.base import BaseDeviceController
from hub.modules.devices.controllers.switching.light import LightDevice
from hub.modules.devices.controllers.sensors.climate import SensorDevice
from hub.modules.devices.controllers.hvac.thermostat import HvacDevice
from hub.modules.devices.controllers.security.lock import SecurityDevice
from hub.core.device_types import DeviceRegistry

class DeviceFactory:
    """
    Fábrica inteligente que reconoce la categoría, código y capacidades
    de un dispositivo en la base de datos y retorna su controlador
    especializado (subclase de BaseDeviceController).
    """

    @staticmethod
    def get_controller(dev: Device) -> BaseDeviceController:
        if not dev:
            return None

        try:
            t_code = int(dev.type_code)
        except (ValueError, TypeError):
            t_code = 0

        category = (dev.category or "").lower()
        feature_keys = dev.feature_keys
        if isinstance(feature_keys, str):
            import json
            try:
                feature_keys = json.loads(feature_keys)
            except Exception:
                feature_keys = []
        if not isinstance(feature_keys, list):
            feature_keys = []

        # 1. HVAC / Climatización
        if category == "hvac" or t_code in (0x20, 0x21, 0x22, 0x23):
            return HvacDevice(dev)

        # 2. Seguridad / Cerradura
        if category == "security" or t_code in (0x30, 0x31, 0x32, 0x33):
            return SecurityDevice(dev)

        # 3. Switching / Iluminación / Relés Multicanal Bitwise
        if category in ("switching", "light", "actuator") or t_code in (1, 2, 3, 4, 5, 6, 7, 8, 9) or "relay" in feature_keys or "dimmer" in feature_keys:
            return LightDevice(dev)

        # 4. Sensado y Telemetría
        if category == "sensor" or (0x10 <= t_code <= 0x1B) or any(k in feature_keys for k in ["temperature", "humidity", "motion", "energy", "battery"]):
            return SensorDevice(dev)

        # 5. Fallback genérico
        return BaseDeviceController(dev)


class SmartDevice:
    """
    Punto de entrada unificado para gestionar el reconocimiento, persistencia,
    interpretación de paquetes y control de hardware en el Hub Colmena.
    """

    @staticmethod
    def recognize(device_id: str, type_code: int = 0, features: int = 0, name: Optional[str] = None) -> BaseDeviceController:
        """
        Reconoce un dispositivo desde un descubrimiento RF (CMD_DISCOVER),
        consulta su descripción del DeviceRegistry, crea o actualiza el registro
        en la base de datos ORM y retorna el controlador especializado.
        """
        dev = Device.get(device_id)
        if not dev:
            dev = Device(device_id=device_id)

        desc = DeviceRegistry.describe(type_code, features)
        dev.type_code = type_code
        dev.features = features
        dev.type_name = desc.get("type_name", dev.type_name)
        dev.type_icon = desc.get("type_icon", dev.type_icon)
        dev.category = desc.get("category", dev.category)
        dev.feature_keys = desc.get("feature_keys", dev.feature_keys)
        if name:
            dev.name = name
        elif dev.name in ("Unknown", "generic", None, ""):
            dev.name = f"{desc.get('type_name', 'Nodo')} {device_id}"

        current_state = dev.state if isinstance(dev.state, dict) else {}
        feature_keys = desc.get("feature_keys", [])
        if "relay" in feature_keys or desc.get("category") in ("switching", "light", "actuator"):
            current_state.setdefault("on", False)
            current_state.setdefault("mask", 0)
            for i in range(1, 17):
                current_state.setdefault(f"ch{i}", False)
        if "dimmer" in feature_keys:
            current_state.setdefault("brightness", 0)
        dev.state = current_state

        dev.save()
        return DeviceFactory.get_controller(dev)

    @staticmethod
    def from_id(device_id: str) -> Optional[BaseDeviceController]:
        """
        Obtiene el controlador especializado de un dispositivo por su ID.
        """
        dev = Device.get(device_id)
        return DeviceFactory.get_controller(dev) if dev else None

    @staticmethod
    def from_orm(dev: Device) -> Optional[BaseDeviceController]:
        """
        Convierte una instancia ORM Device en su controlador especializado.
        """
        return DeviceFactory.get_controller(dev)
