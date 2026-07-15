import datetime
from typing import Optional, Dict, Any, List, Tuple
from hub.core.device_types import DeviceRegistry

class BaseDeviceController:
    """
    Clase base para la gestión modular, interpretación y control de cualquier
    dispositivo de la Colmena IoT.
    Cada tipo de dispositivo (luces, sensores, enchufes, climatización, seguridad)
    hereda de esta clase e implementa su propia lógica especializada.
    """

    def __init__(self, orm_device):
        self.orm_device = orm_device

    @property
    def device_id(self) -> str:
        return self.orm_device.device_id

    @property
    def name(self) -> str:
        return self.orm_device.name

    @property
    def type_code(self) -> int:
        try:
            return int(self.orm_device.type_code)
        except (ValueError, TypeError):
            return 0

    @property
    def type_name(self) -> str:
        return self.orm_device.type_name

    @property
    def category(self) -> str:
        return self.orm_device.category

    @property
    def features(self) -> int:
        try:
            return int(self.orm_device.features)
        except (ValueError, TypeError):
            return 0

    @property
    def feature_keys(self) -> List[str]:
        keys = self.orm_device.feature_keys or []
        if isinstance(keys, str):
            import json
            try:
                keys = json.loads(keys)
            except Exception:
                keys = []
        return keys if isinstance(keys, list) else []

    @property
    def state(self) -> Dict[str, Any]:
        st = self.orm_device.state
        return st if isinstance(st, dict) else {}

    @property
    def rssi(self) -> int:
        return getattr(self.orm_device, "rssi", 0)

    @property
    def status(self) -> str:
        return getattr(self.orm_device, "status", "offline")

    def can_receive(self) -> List[Dict[str, Any]]:
        """
        Devuelve qué parámetros y comandos PUEDE RECIBIR este dispositivo
        desde el Hub o desde la App en la nube.
        Sobrescrito en subclases especializadas.
        """
        return []

    def can_send(self) -> List[Dict[str, Any]]:
        """
        Devuelve qué telemetría o sensores PUEDE ENVIAR este dispositivo
        hacia el Hub (parámetros de lectura/reporte).
        Sobrescrito en subclases especializadas.
        """
        return []

    def decode_rx(self, cmd: int, raw_data: List[int]) -> Dict[str, Any]:
        """
        Interpreta y decodifica los bytes crudos (raw_data) provenientes de un paquete RF
        (CMD_HEARTBEAT=4, CMD_REPORT=2, CMD_SYNC=3) convirtiéndolos en un diccionario de estado limpio.
        """
        return {}

    def encode_tx(self, params: Dict[str, Any]) -> Tuple[int, List[int]]:
        """
        Convierte un diccionario de parámetros de alto nivel en un comando de protocolo
        y su array de bytes (command_byte, data_payload) listo para transmitir por hardware.
        """
        return (0x10, [0] * 26)

    def save_to_db(self, payload: Dict[str, Any], rssi: Optional[int] = None):
        """
        Actualiza el estado interpretado en el modelo ORM y persiste en la base de datos SQLite.
        Sincroniza con el servidor en la nube si está habilitado.
        """
        if not payload:
            return
            
        current_state = self.state.copy()
        current_state.update(payload)
        self.orm_device.state = current_state
        self.orm_device.last_seen = datetime.datetime.now().isoformat()
        self.orm_device.status = "online"
        if rssi is not None:
            self.orm_device.rssi = rssi
        self.orm_device.update(current_state, rssi)

    def execute_command(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """
        Valida, codifica y envía un comando al hardware a través del Gateway.
        Devuelve el nuevo estado aplicado.
        """
        from hub.modules.communication.logic.gateway import gateway
        
        # Obtener id numérico de destino
        dest_id = 0
        if str(self.device_id).startswith("dev_"):
            try:
                dest_id = int(str(self.device_id).split("_")[1])
            except ValueError:
                pass
        elif str(self.device_id).isdigit():
            dest_id = int(str(self.device_id))

        if dest_id > 0:
            cmd_byte, data_payload = self.encode_tx(params)
            gateway.send_command(
                dest_id=dest_id,
                command=cmd_byte,
                device_type=self.type_code,
                data=data_payload
            )

        # Actualizar estado local
        self.save_to_db(params)
        return {"ok": True, "state": self.state, "device": self.orm_device.to_dict()}

    def describe(self) -> Dict[str, Any]:
        """
        Descripción completa de capacidades e interfaz del dispositivo.
        """
        return {
            "device_id": self.device_id,
            "name": self.name,
            "type_code": self.type_code,
            "type_name": self.type_name,
            "category": self.category,
            "features": self.features,
            "feature_keys": self.feature_keys,
            "status": self.status,
            "state": self.state,
            "can_receive": self.can_receive(),
            "can_send": self.can_send(),
            "registry_info": DeviceRegistry.describe(self.type_code, self.features)
        }
