import os
import json
import logging
import threading
import requests
from datetime import datetime
from hub.modules.communication.models.notification import DeviceToken, NotificationLog

logger = logging.getLogger("PushNotifier")

# URL del servidor externo (bridge) que tiene las credenciales Firebase
_BRIDGE_URL = None
_HUB_ID = None
_HUB_SECRET = None

def _init_bridge():
    global _BRIDGE_URL, _HUB_ID, _HUB_SECRET
    if _BRIDGE_URL is None:
        _BRIDGE_URL = (os.environ.get("CLOUD_SERVER_URL") or os.environ.get("CLOUD_BRIDGE_URL", "")).rstrip("/")
        _HUB_ID = os.environ.get("HUB_ID", "")
        _HUB_SECRET = os.environ.get("HUB_RELAY_SECRET", "")

class PushNotifier:
    """
    Motor de notificaciones push para el Hub Colmena.
    Envía notificaciones a los tokens de Firebase Cloud Messaging (FCM) registrados por la app Flutter.
    Proyecto Firebase: si2parcial-9e9e9 (SenderId: 76539049876)

    Flujo:
      1. Guarda la notificación en historial SQLite local.
      2. Intenta despachar el push via el Bridge Server externo (que tiene el Service Account JSON de Firebase).
      3. Si no hay bridge disponible, muestra el mensaje en consola.
    """

    @classmethod
    def send_notification(cls, title: str, body: str, event_type: str = "info", device_id: str = "", priority: str = "high", extra_data: dict = None):
        if extra_data is None:
            extra_data = {}

        # 1. Guardar en historial SQLite
        try:
            log_item = NotificationLog(
                ts=datetime.now().isoformat(),
                title=title,
                body=body,
                event_type=event_type,
                device_id=device_id,
                priority=priority,
                status="pending"
            )
            log_item.save()
        except Exception as e:
            logger.error(f"Error al guardar log de notificación: {e}")

        # 2. Despachar en hilo separado para no bloquear el Hub
        payload = {
            "title": title,
            "body": body,
            "event_type": event_type,
            "device_id": device_id,
            "priority": priority,
            "data": {k: str(v) for k, v in extra_data.items()}
        }
        threading.Thread(target=cls._dispatch_async, args=(payload,), daemon=True, name="PushNotifier").start()
        return True

    @classmethod
    def _dispatch_async(cls, payload: dict):
        """Envía el push al Bridge Server externo (que tiene Firebase Service Account)."""
        _init_bridge()

        title = payload.get("title", "")
        body  = payload.get("body", "")

        if not _BRIDGE_URL or not _HUB_ID:
            logger.info(f"[NOTIF LOCAL] {title}: {body}")
            return

        try:
            url = f"{_BRIDGE_URL}/api/hubs/{_HUB_ID}/notify"
            headers = {
                "Content-Type": "application/json",
                "X-Hub-Id": _HUB_ID,
                "X-Hub-Secret": _HUB_SECRET,
            }
            resp = requests.post(url, headers=headers, json=payload, timeout=8)
            if resp.status_code in (200, 201):
                logger.info(f"[NOTIF PUSH] Enviada: '{title}'")
            else:
                logger.warning(f"[NOTIF PUSH] Respuesta {resp.status_code}: {resp.text[:120]}")
        except Exception as e:
            logger.warning(f"[NOTIF PUSH] No se pudo enviar al bridge ({_BRIDGE_URL}): {e}")
            logger.info(f"[NOTIF LOCAL] {title}: {body}")

    @classmethod
    def notify_device_connected(cls, dev):
        title = "Dispositivo Vinculado"
        body = f"'{dev.name}' ({dev.type_name}) se conectó a la Colmena."
        cls.send_notification(
            title=title,
            body=body,
            event_type="connected",
            device_id=getattr(dev, "device_id", str(getattr(dev, "id", ""))),
            extra_data={"type": "CONNECTED"}
        )

    @classmethod
    def notify_device_disconnected(cls, dev):
        title = "Dispositivo Desconectado"
        body = f"'{dev.name}' dejó de responder (Offline)."
        cls.send_notification(
            title=title,
            body=body,
            event_type="disconnected",
            device_id=getattr(dev, "device_id", str(getattr(dev, "id", ""))),
            extra_data={"type": "DISCONNECTED"}
        )

    @classmethod
    def notify_device_unpaired(cls, device_id: str, name: str = ""):
        title = "Dispositivo Desvinculado"
        body = f"El dispositivo {name or device_id} fue desvinculado de la Colmena."
        cls.send_notification(
            title=title,
            body=body,
            event_type="unpaired",
            device_id=device_id,
            extra_data={"type": "UNPAIRED", "device_id": device_id}
        )

    @classmethod
    def notify_skill_action(cls, skill_name: str, message: str, priority: str = "high", extra: dict = None):
        title = f"Skill Colmena: {skill_name}"
        cls.send_notification(
            title=title,
            body=message,
            event_type="skill",
            priority=priority,
            extra_data=extra or {"type": "SKILL"}
        )
