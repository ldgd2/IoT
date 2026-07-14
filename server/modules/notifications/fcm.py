# =============================================================
# server/modules/notifications/fcm.py
# Servicio de notificaciones push via Firebase Cloud Messaging
# Usa el archivo .json de credenciales de Service Account
# =============================================================
import os
import json
import time
import threading
import requests
from pathlib import Path
from datetime import datetime

# ── Localización del archivo de credenciales ──────────────────
_CRED_DIR = Path(__file__).parent.parent.parent / "credenciales"
_CRED_FILE = None

def _find_credential_file() -> Path | None:
    """Busca automáticamente el primer .json de Service Account en /credenciales."""
    global _CRED_FILE
    if _CRED_FILE and _CRED_FILE.exists():
        return _CRED_FILE
    if _CRED_DIR.exists():
        for f in _CRED_DIR.glob("*.json"):
            if f.name != ".gitkeep":
                _CRED_FILE = f
                return _CRED_FILE
    # Fallback: variable de entorno
    env_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if env_path and Path(env_path).exists():
        _CRED_FILE = Path(env_path)
        return _CRED_FILE
    return None


# ── OAuth2 Token (con google-auth oficial de Google) ──────────
_token_cache = {"access_token": None, "expires_at": 0}
_token_lock = threading.Lock()

_SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

def _get_access_token() -> str | None:
    """Obtiene (o reutiliza del caché) el Bearer token de OAuth2 de Google usando google-auth."""
    with _token_lock:
        if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
            return _token_cache["access_token"]

        cred_file = _find_credential_file()
        if not cred_file:
            print("[FCM] ⚠️  No se encontró archivo de credenciales Firebase (.json)")
            return None

        try:
            from google.oauth2 import service_account
            import google.auth.transport.requests

            credentials = service_account.Credentials.from_service_account_file(
                str(cred_file), scopes=_SCOPES
            )
            request = google.auth.transport.requests.Request()
            credentials.refresh(request)
            _token_cache["access_token"] = credentials.token
            if credentials.expiry:
                _token_cache["expires_at"] = credentials.expiry.timestamp()
            else:
                _token_cache["expires_at"] = time.time() + 3500
            return _token_cache["access_token"]
        except ImportError:
            print("[FCM] ⚠️  Faltan dependencias de Google. Instálalas con: pip install google-auth cryptography requests")
            return None
        except Exception as e:
            print(f"[FCM] ⚠️  Excepción al obtener token OAuth2 con google-auth: {e}")
            return None



def _get_project_id() -> str | None:
    """Lee el project_id desde el archivo de credenciales."""
    cred_file = _find_credential_file()
    if not cred_file:
        return None
    try:
        data = json.loads(cred_file.read_text(encoding="utf-8"))
        return data.get("project_id")
    except Exception:
        return None


# ── Envío de Notificación Push ────────────────────────────────
def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None) -> bool:
    """
    Envía una notificación push a un dispositivo via FCM HTTP v1 API.
    
    Args:
        fcm_token: Token FCM del dispositivo destino.
        title: Título de la notificación.
        body: Cuerpo del mensaje.
        data: Payload de datos adicionales (opcional).
    
    Returns:
        True si se envió exitosamente, False en caso contrario.
    """
    if not fcm_token:
        return False

    access_token = _get_access_token()
    if not access_token:
        return False

    project_id = _get_project_id()
    if not project_id:
        print("[FCM] ⚠️  No se encontró project_id en las credenciales.")
        return False

    fcm_url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

    message = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": body,
            },
            "android": {
                "priority": "high",
                "notification": {
                    "channel_id": "colmena_high_importance_channel",
                    "sound": "default",
                },
            },
            "apns": {
                "payload": {
                    "aps": {
                        "alert": {"title": title, "body": body},
                        "sound": "default",
                        "badge": 1,
                    }
                }
            },
        }
    }

    if data:
        # FCM data payload: todos los valores deben ser strings
        message["message"]["data"] = {k: str(v) for k, v in data.items()}

    try:
        resp = requests.post(
            fcm_url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json=message,
            timeout=10,
        )
        if resp.status_code == 200:
            print(f"[FCM] ✅ Notificación enviada: '{title}'")
            return True
        else:
            print(f"[FCM] ⚠️  Error FCM {resp.status_code}: {resp.text}")
            return False
    except Exception as e:
        print(f"[FCM] ⚠️  Excepción al enviar notificación: {e}")
        return False


def notify_device_offline(hub_id: str, device_name: str, device_id: str):
    """
    Notifica a todos los usuarios dueños del hub y a todos sus telefonos M:N
    que un dispositivo se desconecto (paso a estado offline).
    """
    from server.db import database as db

    # Obtener todos los usuarios propietarios del hub
    rows = db.execute(
        "SELECT u.user_id, u.username FROM users u "
        "JOIN hubs h ON u.user_id = h.user_id "
        "WHERE h.hub_id = ?",
        (hub_id,),
    ).fetchall()

    title = "Dispositivo desconectado"
    body = f"El dispositivo '{device_name}' se desconecto y esta offline."

    for row in rows:
        user = dict(row)
        user_id = user["user_id"]

        # Guardar notificacion en BD (historial)
        db.execute(
            "INSERT INTO notifications (user_id, hub_id, device_id, title, body, event_type, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (user_id, hub_id, device_id, title, body, "device_offline", datetime.now().isoformat()),
        )

        # Obtener todos los tokens del usuario (M:N de user_fcm_tokens + users.fcm_token)
        token_rows = db.execute(
            "SELECT DISTINCT fcm_token FROM ("
            "  SELECT fcm_token FROM users WHERE user_id = ? AND fcm_token != '' "
            "  UNION "
            "  SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ? AND fcm_token != ''"
            ")",
            (user_id, user_id)
        ).fetchall()

        tokens = [dict(t)["fcm_token"] for t in token_rows if dict(t).get("fcm_token")]

        if tokens:
            for token in tokens:
                threading.Thread(
                    target=send_push_notification,
                    args=(token, title, body),
                    kwargs={"data": {"hub_id": hub_id, "device_id": device_id, "event": "device_offline"}},
                    daemon=True,
                ).start()
            print(f"[FCM] Notificacion de desconexion enviada a {len(tokens)} telefonos del usuario '{user.get('username')}'.")
        else:
            print(f"[FCM] Usuario '{user.get('username')}' sin FCM tokens registrados.")

