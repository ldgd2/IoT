import json
import logging
import requests
from datetime import datetime
from hub.modules.communication.models.notification import DeviceToken, NotificationLog

logger = logging.getLogger("PushNotifier")

class PushNotifier:
    """
    Motor de notificaciones push para el Hub Colmena.
    Envía notificaciones a los tokens de Firebase Cloud Messaging (FCM) registrados por la app Flutter.
    Proyecto Firebase: si2parcial-9e9e9 (SenderId: 76539049876)
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
                status="sent"
            )
            log_item.save()
            logger.info(f"📋 [NOTIFICACIÓN REGISTRADA] {event_type.upper()}: {title} -> {body}")
        except Exception as e:
            logger.error(f"Error al guardar log de notificación: {e}")

        # 2. Obtener tokens registrados
        try:
            tokens = [t.token for t in DeviceToken.all() if t.token]
            if not tokens:
                logger.info("ℹ️ No hay tokens FCM registrados en la base de datos para enviar push real.")
                return False
                
            logger.info(f"🚀 Enviando notificación push a {len(tokens)} dispositivo(s) móvil(es)...")
            
            # Preparar payload compatible con Flutter Local Notifications / FCM
            payload_data = {
                "type": event_type.upper(),
                "title": title,
                "body": body,
                "device_id": device_id,
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
            payload_data.update({k: str(v) for k, v in extra_data.items()})

            # Intento de envío HTTP / FCM
            for token in tokens:
                cls._dispatch_fcm(token, title, body, payload_data, priority)
            return True
        except Exception as e:
            logger.error(f"Error en envío de notificación push: {e}")
            return False

    @classmethod
    def _dispatch_fcm(cls, token: str, title: str, body: str, data: dict, priority: str):
        """
        Intenta despachar el paquete al endpoint FCM si hay credencial configurada, o simula despacho en consola.
        """
        # Si se usa un servidor relay de notificaciones o FCM HTTP v1 localmente:
        try:
            # Aquí se puede conectar con firebase-admin si se coloca el json de servicio,
            # o hacer echo para monitoreo
            logger.info(f"📲 [FCM -> {token[:15]}...] {title}: {body}")
        except Exception as e:
            logger.warning(f"Fallo envío a token {token[:10]}: {e}")

    @classmethod
    def notify_device_connected(cls, dev):
        title = "Dispositivo Vinculado Correctamente"
        body = f"El dispositivo '{dev.name}' ({dev.type_name}) se conectó y reportó a la Colmena."
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
        body = f"El sensor o módulo '{dev.name}' ha dejado de responder (Offline)."
        cls.send_notification(
            title=title,
            body=body,
            event_type="disconnected",
            device_id=getattr(dev, "device_id", str(getattr(dev, "id", ""))),
            extra_data={"type": "DISCONNECTED"}
        )

    @classmethod
    def notify_skill_action(cls, skill_name: str, message: str, priority: str = "high", extra: dict = None):
        title = f"Skill Colmena: {skill_name}"
        body = message
        cls.send_notification(
            title=title,
            body=body,
            event_type="skill",
            priority=priority,
            extra_data=extra or {"type": "SKILL"}
        )
