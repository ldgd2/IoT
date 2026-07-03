# =============================================================
# server/config.py
# Configuración del Bridge Server (Teléfono <-> Hub)
# =============================================================
import os

SERVER_HOST = os.environ.get("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.environ.get("SERVER_PORT", 8000))

# URL por defecto del Gateway Hub (donde corre hub/main.py)
HUB_URL = os.environ.get("HUB_URL", "http://127.0.0.1:5000").rstrip("/")

# Tiempo máximo de espera para comandos hacia el Hub (segundos)
HUB_TIMEOUT = int(os.environ.get("HUB_TIMEOUT", 5))
