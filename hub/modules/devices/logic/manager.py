from sqlalchemy.orm import Session
from hub.modules.devices.models.device import Device
from hub.modules.capabilities.models.ontology import DeviceType
import datetime
from rich.console import Console

console = Console()

class DeviceManager:
    """
    Gestiona el ciclo de vida de los Nodos Fisicos (Hardware) en la Colmena.
    Maneja la logica de vinculacion (Pairing) y de evitar duplicaciones de capacidades.
    """
    
    def __init__(self, db_session: Session):
        self.db = db_session

    def process_heartbeat(self, node_id: int, type_id: int):
        """
        Invocado cada vez que el Gateway recibe un latido de un nodo.
        Aqui es donde se resuelve la vinculacion inteligente.
        """
        # 1. Buscar si el dispositivo físico (Foco 1 o Foco 2) ya existe
        device = self.db.query(Device).filter(Device.node_id == node_id).first()
        
        if not device:
            # ¡NUEVO DISPOSITIVO FÍSICO DETECTADO! (Ej. Conectaste tu Foco 2 por primera vez)
            console.print(f"[green]Nuevo dispositivo detectado: Node {node_id} (Tipo {type_id})[/green]")
            device = Device(node_id=node_id, type_id=type_id)
            self.db.add(device)
            self.db.commit()
            
            # 2. Verificar si el Hub conoce este "Tipo de Hardware" (Ej. ¿Conoce qué es el Tipo 2?)
            known_type = self.db.query(DeviceType).filter(DeviceType.type_id == type_id).first()
            if not known_type:
                # El Hub NO conoce este tipo de placa.
                # Aqui es donde se le pediria a la placa que envie su JSON de configuracion,
                # o el Hub lo descarga de internet basandose en el type_id.
                self._request_capabilities_from_node(node_id, type_id)
            else:
                # El Hub YA conoce este tipo (Ej. Porque ya instalaste un Foco 1 antes).
                # No se pide el JSON. Automaticamente el Foco 2 hereda las habilidades.
                console.print(f"[blue]El Hub ya conoce las capacidades del Tipo {type_id}. Omitiendo descarga JSON.[/blue]")
                
        else:
            # DISPOSITIVO YA CONOCIDO (Latido normal cada X segundos)
            # Solo actualizamos su hora de ultima conexion.
            device.last_seen = datetime.datetime.utcnow()
            device.is_online = True
            self.db.commit()

    def _request_capabilities_from_node(self, node_id: int, type_id: int):
        """
        Manda un comando especial a la placa para que inicie la transferencia
        fragmentada de su JSON de capacidades hacia la PC.
        """
        console.print(f"[yellow]Solicitando JSON de Capacidades al Nodo {node_id}...[/yellow]")
        # Logica para enviar paquete CMD_DISCOVER_SCHEMA al nodo
        pass
