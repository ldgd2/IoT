"""
device_types.py — Tabla de traducción de identificadores de dispositivo.

Contraparte Python de shared/protocol/DeviceTypes.h
El backend usa este módulo para traducir los bytes recibidos del gateway
a lenguaje natural, íconos, y metadatos de las interfaces.

Protocolo de 2 bytes por dispositivo:
    device_type (uint8)  → QUÉ es el dispositivo
    features    (uint8)  → QUÉ puede hacer (bitmask de capacidades)

Uso:
    from device_types import DeviceRegistry

    name   = DeviceRegistry.type_name(0x01)       # → "Enchufe"
    feats  = DeviceRegistry.feature_names(0x21)   # → ["relay", "energy_meter"]
    info   = DeviceRegistry.describe(0x02, 0x03)  # → dict completo
"""

from dataclasses import dataclass, field
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# Tipos de dispositivo — espejo de DeviceTypes.h
# ─────────────────────────────────────────────────────────────────────────────

DEVICE_TYPES: dict[int, dict] = {
    # ── Switching (0x0X) ──────────────────────────────────────────────────────
    0x00: {"name": "Desconocido",          "icon": "help-circle.svg", "category": "system"},
    0x01: {"name": "Enchufe",              "icon": "power-plug.svg", "category": "switching"},
    0x02: {"name": "Luz",                  "icon": "lightbulb.svg", "category": "switching"},
    0x03: {"name": "Interruptor",          "icon": "toggle-switch.svg", "category": "switching"},
    0x04: {"name": "Dimmer",               "icon": "brightness-6.svg", "category": "switching"},
    0x05: {"name": "Ventilador",           "icon": "fan.svg", "category": "switching"},
    0x06: {"name": "Persiana",             "icon": "window-shutter.svg", "category": "switching"},
    0x07: {"name": "Válvula",              "icon": "valve.svg", "category": "switching"},
    0x08: {"name": "Bomba",               "icon": "water-pump.svg", "category": "switching"},
    0x09: {"name": "Tira LED",             "icon": "led-strip.svg", "category": "switching"},

    # ── Sensado (0x1X) ────────────────────────────────────────────────────────
    0x10: {"name": "Sensor",               "icon": "access-point.svg", "category": "sensor"},
    0x11: {"name": "Sensor Temperatura",   "icon": "thermometer.svg", "category": "sensor"},
    0x12: {"name": "Sensor Movimiento",    "icon": "motion-sensor.svg", "category": "sensor"},
    0x13: {"name": "Sensor Puerta",        "icon": "door-open.svg", "category": "sensor"},
    0x14: {"name": "Detector Humo",        "icon": "fire.svg", "category": "sensor"},
    0x15: {"name": "Sensor Inundación",    "icon": "water-alert.svg", "category": "sensor"},
    0x16: {"name": "Detector Gas",         "icon": "cloud-alert.svg",  "category": "sensor"},
    0x17: {"name": "Sensor Luz",           "icon": "white-balance-sunny.svg",  "category": "sensor"},
    0x18: {"name": "Sensor Suelo",         "icon": "sprout.svg", "category": "sensor"},
    0x19: {"name": "Medidor Energía",      "icon": "lightning-bolt.svg", "category": "sensor"},
    0x1A: {"name": "Botón Inalámbrico",    "icon": "bell.svg", "category": "sensor"},

    # ── Clima / HVAC (0x2X) ───────────────────────────────────────────────────
    0x20: {"name": "Termostato",           "icon": "thermostat.svg", "category": "hvac"},
    0x21: {"name": "Aire Acondicionado",   "icon": "air-conditioner.svg",  "category": "hvac"},
    0x22: {"name": "Calefactor",           "icon": "radiator.svg",  "category": "hvac"},
    0x23: {"name": "Humidificador",        "icon": "air-humidifier.svg", "category": "hvac"},

    # ── Seguridad (0x3X) ──────────────────────────────────────────────────────
    0x30: {"name": "Cerradura",            "icon": "lock.svg", "category": "security"},
    0x31: {"name": "Cámara",              "icon": "camera.svg", "category": "security"},
    0x32: {"name": "Sirena",              "icon": "alarm-bell.svg", "category": "security"},
    0x33: {"name": "Teclado Acceso",       "icon": "dialpad.svg", "category": "security"},

    # ── Audio/Video (0x4X) ────────────────────────────────────────────────────
    0x40: {"name": "Altavoz",             "icon": "speaker.svg", "category": "media"},
    0x41: {"name": "Panel Info",           "icon": "monitor.svg",  "category": "media"},

    # ── Sistema (0xFX) ────────────────────────────────────────────────────────
    0xF0: {"name": "Gateway",             "icon": "router-wireless.svg", "category": "system"},
    0xF1: {"name": "Repetidor",           "icon": "access-point-network.svg", "category": "system"},
    0xFF: {"name": "Broadcast",           "icon": "broadcast.svg", "category": "system"},
}

# ─────────────────────────────────────────────────────────────────────────────
# Feature Flags — espejo de DeviceTypes.h FEAT_*
# ─────────────────────────────────────────────────────────────────────────────

FEATURE_FLAGS: dict[int, dict] = {
    0x01: {"key": "relay",        "name": "Relay ON/OFF",        "icon": "power.svg"},
    0x02: {"key": "dimmer",       "name": "Control de brillo",   "icon": "brightness-6.svg"},
    0x04: {"key": "temperature",  "name": "Temperatura",         "icon": "thermometer.svg"},
    0x08: {"key": "humidity",     "name": "Humedad",             "icon": "water-percent.svg"},
    0x10: {"key": "motion",       "name": "Movimiento / PIR",    "icon": "motion-sensor.svg"},
    0x20: {"key": "energy",       "name": "Medición energía",    "icon": "lightning-bolt.svg"},
    0x40: {"key": "display",      "name": "Pantalla local",      "icon": "monitor.svg"},
    0x80: {"key": "battery",      "name": "Batería",             "icon": "battery.svg"},
}


# ─────────────────────────────────────────────────────────────────────────────
# DeviceRegistry — API de traducción
# ─────────────────────────────────────────────────────────────────────────────

class DeviceRegistry:

    @staticmethod
    def type_info(device_type: int) -> dict:
        """Retorna el dict de metadata del tipo, o un dict 'Desconocido'."""
        return DEVICE_TYPES.get(device_type, DEVICE_TYPES[0x00])

    @staticmethod
    def type_name(device_type: int) -> str:
        """Retorna el nombre legible del tipo de dispositivo."""
        return DeviceRegistry.type_info(device_type)["name"]

    @staticmethod
    def type_icon(device_type: int) -> str:
        """Retorna el emoji/ícono del tipo de dispositivo."""
        return DeviceRegistry.type_info(device_type)["icon"]

    @staticmethod
    def type_category(device_type: int) -> str:
        """Retorna la categoría del tipo de dispositivo."""
        return DeviceRegistry.type_info(device_type)["category"]

    @staticmethod
    def feature_names(features: int) -> list[str]:
        """Retorna lista de keys de features activas en el bitmask."""
        return [
            info["key"]
            for bit, info in FEATURE_FLAGS.items()
            if features & bit
        ]

    @staticmethod
    def feature_labels(features: int) -> list[str]:
        """Retorna lista de nombres legibles de features activas."""
        return [
            info["name"]
            for bit, info in FEATURE_FLAGS.items()
            if features & bit
        ]

    @staticmethod
    def has_feature(features: int, flag: int) -> bool:
        """Verifica si el bitmask tiene una feature específica."""
        return bool(features & flag)

    @staticmethod
    def describe(device_type: int, features: int) -> dict:
        """
        Descripción completa de un dispositivo en un solo dict.

        Retorna:
            {
                "type_code":   0x02,
                "type_name":   "Luz",
                "type_icon":   "💡",
                "category":    "switching",
                "features":    0x03,
                "feature_keys": ["relay", "dimmer"],
                "feature_labels": ["Relay ON/OFF", "Control de brillo"]
            }
        """
        info = DeviceRegistry.type_info(device_type)
        return {
            "type_code":      device_type,
            "type_name":      info["name"],
            "type_icon":      info["icon"],
            "category":       info["category"],
            "features":       features,
            "feature_keys":   DeviceRegistry.feature_names(features),
            "feature_labels": DeviceRegistry.feature_labels(features),
        }

    @staticmethod
    def all_types() -> list[dict]:
        """Retorna todos los tipos registrados como lista de dicts."""
        return [
            {"code": code, **meta}
            for code, meta in sorted(DEVICE_TYPES.items())
        ]


# ─────────────────────────────────────────────────────────────────────────────
# Constantes — mismo naming que DeviceTypes.h para consistencia
# ─────────────────────────────────────────────────────────────────────────────

# Device types
DEV_UNKNOWN      = 0x00
DEV_PLUG         = 0x01
DEV_LIGHT        = 0x02
DEV_SWITCH       = 0x03
DEV_DIMMER       = 0x04
DEV_FAN          = 0x05
DEV_CURTAIN      = 0x06
DEV_VALVE        = 0x07
DEV_PUMP         = 0x08
DEV_STRIP        = 0x09

DEV_SENSOR       = 0x10
DEV_SENSOR_TEMP  = 0x11
DEV_SENSOR_PIR   = 0x12
DEV_SENSOR_DOOR  = 0x13
DEV_SENSOR_SMOKE = 0x14
DEV_SENSOR_FLOOD = 0x15
DEV_SENSOR_GAS   = 0x16
DEV_SENSOR_LUX   = 0x17
DEV_SENSOR_SOIL  = 0x18
DEV_SENSOR_POWER = 0x19
DEV_SENSOR_BTN   = 0x1A

DEV_THERMOSTAT   = 0x20
DEV_AC           = 0x21
DEV_HEATER       = 0x22
DEV_HUMIDIFIER   = 0x23

DEV_LOCK         = 0x30
DEV_CAMERA       = 0x31
DEV_SIREN        = 0x32
DEV_KEYPAD       = 0x33

DEV_SPEAKER      = 0x40
DEV_DISPLAY_NODE = 0x41

DEV_GATEWAY      = 0xF0
DEV_REPEATER     = 0xF1
DEV_ALL          = 0xFF

# Feature flags
FEAT_RELAY    = 0x01
FEAT_DIMMER   = 0x02
FEAT_TEMP     = 0x04
FEAT_HUMIDITY = 0x08
FEAT_MOTION   = 0x10
FEAT_ENERGY   = 0x20
FEAT_DISPLAY  = 0x40
FEAT_BATTERY  = 0x80


# ─── Demo / test ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys, io
    # Forzar UTF-8 en la salida del terminal (Windows)
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

    print("=== Device Type Registry ===\n")

    examples = [
        (DEV_PLUG,   FEAT_RELAY | FEAT_ENERGY,                "Enchufe con medicion"),
        (DEV_LIGHT,  FEAT_RELAY | FEAT_DIMMER,                "Tira LED regulable"),
        (DEV_SENSOR, FEAT_TEMP | FEAT_HUMIDITY | FEAT_MOTION, "Sensor multi"),
        (DEV_LOCK,   FEAT_RELAY | FEAT_BATTERY,               "Cerradura con bateria"),
        (DEV_GATEWAY, 0,                                       "Gateway"),
    ]

    for dev_type, features, label in examples:
        d = DeviceRegistry.describe(dev_type, features)
        print(f"  [{label}]")
        print(f"    type_code : 0x{d['type_code']:02X}")
        print(f"    type_name : {d['type_name']}")
        print(f"    category  : {d['category']}")
        feats = ', '.join(d['feature_labels']) or 'ninguna'
        print(f"    features  : 0x{d['features']:02X} -> {feats}")
        print()

