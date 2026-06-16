import os
from pathlib import Path
from dotenv import load_dotenv

ROOT_DIR = Path(__file__).parent.parent.parent.resolve()
HUB_DIR = ROOT_DIR / "hub"
LOG_DIR = ROOT_DIR / "logs"
DB_FILE = HUB_DIR / "db" / "data.sqlite"
PID_FILE = ROOT_DIR / ".hub.pid"
VENV_DIR = ROOT_DIR / ".venv"
ENV_FILE = HUB_DIR / ".env"

load_dotenv(ENV_FILE)

LOG_DIR.mkdir(exist_ok=True)
DB_FILE.parent.mkdir(exist_ok=True)

# Valores cargados del .env con fallbacks por defecto
import sys
default_port = "COM3" if sys.platform == "win32" else "/dev/ttyUSB0"

API_PORT = int(os.getenv("API_PORT", 5000))
RF_PORT = os.getenv("RF_PORT", default_port)
RF_BAUD = int(os.getenv("RF_BAUD", 9600))

# Coordenadas por defecto para el Clima (Ej: La Paz, Bolivia)
LATITUDE = float(os.getenv("LATITUDE", -16.5000))
LONGITUDE = float(os.getenv("LONGITUDE", -68.1193))
