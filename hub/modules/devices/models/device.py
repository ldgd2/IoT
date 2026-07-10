from hub.db.database import BaseModel, Field, Database

class Device(BaseModel):
    __table__ = "devices"
    
    device_id = Field("TEXT", primary_key=True)
    name = Field("TEXT", default="Unknown")
    type_code = Field("INTEGER", default=0)
    type_name = Field("TEXT", default="generic")
    type_icon = Field("TEXT", default="help-circle.svg")
    category = Field("TEXT", default="system")
    features = Field("INTEGER", default=0)
    feature_keys = Field("TEXT", default=[])
    status = Field("TEXT", default="offline")
    state = Field("TEXT", default={})
    last_seen = Field("TEXT", default="")
    rssi = Field("INTEGER", default=0)
    msg_count = Field("INTEGER", default=0)

    @classmethod
    def migrate(cls):
        """Agrega columnas nuevas al esquema sin borrar datos existentes."""
        cursor = Database.execute(f"PRAGMA table_info({cls.__table__})")
        existing_cols = {row[1] for row in cursor.fetchall()}

        for col_name, field in cls._get_fields().items():
            if col_name not in existing_cols:
                default_val = field.default
                if isinstance(default_val, (dict, list)):
                    default_val = "'{}'" if isinstance(default_val, dict) else "'[]'"
                elif isinstance(default_val, str):
                    default_val = f"'{default_val}'"
                elif default_val is None:
                    default_val = "NULL"
                try:
                    Database.execute(
                        f"ALTER TABLE {cls.__table__} ADD COLUMN {col_name} {field.type_name} DEFAULT {default_val}"
                    )
                except Exception:
                    pass  # Columna ya existe o error de tipo

    def update(self, payload: dict, rssi: int = None):
        self.state = payload
        import datetime
        self.last_seen = datetime.datetime.now().isoformat()
        self.status = "online"
        if rssi is not None:
            self.rssi = rssi
        self.msg_count += 1
        self.save()

    @property
    def feature_labels(self):
        from hub.core.device_types import DeviceRegistry
        feats = self.features
        if not isinstance(feats, int):
            try: feats = int(feats)
            except: feats = 0
        return DeviceRegistry.feature_labels(feats)

    @property
    def registry_info(self):
        from hub.core.device_types import DeviceRegistry
        feats = self.features
        t_code = self.type_code
        if not isinstance(feats, int):
            try: feats = int(feats)
            except: feats = 0
        if not isinstance(t_code, int):
            try: t_code = int(t_code)
            except: t_code = 0
        return DeviceRegistry.describe(t_code, feats)

    @property
    def modifiable_params(self):
        """Retorna lista de parámetros y capacidades que este dispositivo permite modificar desde el Hub."""
        keys = self.feature_keys or []
        if isinstance(keys, str):
            import json
            try: keys = json.loads(keys)
            except: keys = []
        if not isinstance(keys, list):
            keys = []
            
        try:
            t_code = int(self.type_code)
        except:
            t_code = 0

        name_lower = (self.name or "").lower()
        id_lower = (self.device_id or "").lower()
        is_light = any(kw in name_lower for kw in ["luz", "foco", "lámpara", "lampara", "bombilla", "dimmer"])
        is_switch = is_light or any(kw in name_lower for kw in ["relay", "enchufe", "switch", "sala", "afuera", "patio", "cuarto", "cocina", "baño", "jardin"]) or ("dev_" in id_lower and "sensor" not in name_lower)

        params = []
        # Relay / Switching (Luz o Actuador)
        if "relay" in keys or self.category in ("switching", "light", "actuator") or t_code in (1, 2, 3, 5, 7, 8) or is_switch:
            params.append({
                "key": "on",
                "label": "Estado / Encendido (ON / OFF)",
                "type": "Booleano (True / False)",
                "control": "switch",
                "desc": "Control de encendido y apagado del dispositivo.",
                "default": False
            })
        # Dimmer PWM (Regulador de Luz / Brillo)
        if "dimmer" in keys or t_code in (2, 4, 9) or is_light:
            params.append({
                "key": "brightness",
                "label": "Intensidad de Brillo",
                "type": "Entero (0 - 255)",
                "control": "slider",
                "desc": "Ajuste de intensidad luminosa (0 a 100%).",
                "default": 255
            })
        # Persiana / Cortina
        if t_code == 6 or any(kw in name_lower for kw in ["persiana", "cortina", "curtain", "blind"]):
            params.append({
                "key": "position",
                "label": "Posición de Apertura",
                "type": "Entero (0 - 100%)",
                "control": "slider",
                "desc": "Nivel de apertura de la persiana o cortina (0% cerrada, 100% abierta).",
                "default": 0
            })
        # Termostato / Clima HVAC
        if t_code in (0x20, 0x21, 0x22) or self.category == "hvac" or any(kw in name_lower for kw in ["clima", "termostato", "hvac", "aire"]):
            params.append({
                "key": "target_temp",
                "label": "Temperatura Consigna (°C)",
                "type": "Decimal (°C)",
                "control": "number",
                "desc": "Temperatura objetivo para el control automático del climatizador.",
                "default": 22.0
            })
            params.append({
                "key": "mode",
                "label": "Modo Operativo HVAC",
                "type": "Texto ('cool' | 'heat' | 'auto' | 'off')",
                "control": "select",
                "desc": "Modo de funcionamiento del climatizador.",
                "default": "auto"
            })
        # Cerradura / Seguridad
        if t_code == 0x30 or self.category == "security" or any(kw in name_lower for kw in ["cerradura", "chapa", "lock", "puerta"]):
            params.append({
                "key": "locked",
                "label": "Estado de la Cerradura",
                "type": "Booleano (True / False)",
                "control": "switch",
                "desc": "Control de bloqueo de la cerradura inteligente.",
                "default": True
            })
        return params

    @property
    def readonly_params(self):
        """Retorna lista de sensores o telemetría de hardware que son de solo lectura."""
        keys = self.feature_keys or []
        if isinstance(keys, str):
            import json
            try: keys = json.loads(keys)
            except: keys = []
        if not isinstance(keys, list):
            keys = []
            
        try:
            t_code = int(self.type_code)
        except:
            t_code = 0

        name_lower = (self.name or "").lower()

        params = []
        if "temperature" in keys or t_code == 0x11 or any(kw in name_lower for kw in ["temp", "temperatura", "clima", "ambiental"]):
            params.append({"key": "temperature", "unit": "°C", "label": "Sensor de Temperatura", "desc": "Medición térmica en tiempo real."})
        if "humidity" in keys or any(kw in name_lower for kw in ["humedad", "higrometro", "humidity"]):
            params.append({"key": "humidity", "unit": "%", "label": "Sensor de Humedad", "desc": "Humedad relativa en el ambiente."})
        if "motion" in keys or t_code == 0x12 or any(kw in name_lower for kw in ["movimiento", "pir", "motion", "presencia"]):
            params.append({"key": "motion", "unit": "PIR", "label": "Detector de Movimiento", "desc": "Detección de presencia en el área."})
        if "energy" in keys or t_code == 0x19 or any(kw in name_lower for kw in ["consumo", "medidor", "potencia", "power", "energy"]):
            params.append({"key": "power", "unit": "W", "label": "Consumo de Potencia", "desc": "Consumo eléctrico en tiempo real."})
            params.append({"key": "voltage", "unit": "V", "label": "Voltaje de Red", "desc": "Tensión o voltaje medido."})
        if "battery" in keys:
            params.append({"key": "battery", "unit": "%", "label": "Nivel de Batería", "desc": "Carga de batería restante."})
        return params

    def to_dict(self):
        data = {k: getattr(self, k) for k in self._get_fields()}
        data["feature_labels"] = self.feature_labels
        data["modifiable_params"] = self.modifiable_params
        data["readonly_params"] = self.readonly_params
        data["registry_info"] = self.registry_info
        return data

