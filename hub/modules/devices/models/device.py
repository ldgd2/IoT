from hub.db.database import BaseModel, Field, Database

class Device(BaseModel):
    __table__ = "devices"
    
    device_id = Field("TEXT", primary_key=True)
    name = Field("TEXT", default="Unknown")
    user_id = Field("TEXT", default="")
    room = Field("TEXT", default="")
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
        if isinstance(self.state, dict) and isinstance(payload, dict):
            self.state.update(payload)
        else:
            self.state = payload
        import datetime
        self.last_seen = datetime.datetime.now().isoformat()
        self.status = "online"
        if rssi is not None:
            self.rssi = rssi
        self.msg_count += 1
        self.save()
        try:
            from hub.modules.communication.logic.cloud_bridge import cloud_bridge
            cloud_bridge._sync_devices()
            cloud_bridge.send_event("device_updated", self.to_dict())
        except Exception:
            pass

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
    def controller(self):
        """Retorna el controlador modular y especializado para este dispositivo (LightDevice, SensorDevice, HvacDevice, etc.)."""
        from hub.modules.devices.device import DeviceFactory
        return DeviceFactory.get_controller(self)

    @property
    def modifiable_params(self):
        """Retorna lista de parámetros delegando al controlador modular según su tipo y capacidades."""
        ctrl = self.controller
        return ctrl.can_receive() if ctrl else []

    @property
    def readonly_params(self):
        """Retorna lista de sensores o telemetría delegando al controlador modular según su tipo y capacidades."""
        ctrl = self.controller
        return ctrl.can_send() if ctrl else []

    def to_dict(self):
        data = {k: getattr(self, k) for k in self._get_fields()}
        data["feature_labels"] = self.feature_labels
        data["modifiable_params"] = self.modifiable_params
        data["readonly_params"] = self.readonly_params
        data["registry_info"] = self.registry_info
        return data

