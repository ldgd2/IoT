from collections import defaultdict
from typing import Callable, Any

class EventBus:
    """
    Sistema Pub/Sub (Publish-Subscribe) para el Motor de Automatizacion.
    Permite que los nodos de hardware, temporizadores o agentes externos
    publiquen eventos, y que las Skills se suscriban a ellos.
    """
    def __init__(self):
        # event_name -> list of callback functions
        self.subscribers = defaultdict(list)

    def subscribe(self, event_name: str, callback: Callable[[Any], None]):
        """Suscribe una funcion a un evento especifico."""
        self.subscribers[event_name].append(callback)

    def publish(self, event_name: str, payload: Any = None):
        """Dispara un evento. Todos los callbacks suscritos seran llamados."""
        if event_name in self.subscribers:
            for callback in self.subscribers[event_name]:
                try:
                    callback(payload)
                except Exception as e:
                    from rich.console import Console
                    Console().print(f"[red]Error en callback de EventBus para {event_name}: {e}[/red]")

# Instancia global del EventBus para toda la app
event_bus = EventBus()
