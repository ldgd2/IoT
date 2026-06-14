import os
from pathlib import Path
from dotenv import load_dotenv

ROOT_DIR = Path(__file__).parent.parent.parent.resolve()
SERVER_DIR = ROOT_DIR / "server"
LOG_DIR = ROOT_DIR / "logs"
DB_FILE = SERVER_DIR / "db" / "data.sqlite"
PID_FILE = ROOT_DIR / ".server.pid"
VENV_DIR = ROOT_DIR / ".venv"
ENV_FILE = ROOT_DIR / ".env"

load_dotenv(ENV_FILE)

LOG_DIR.mkdir(exist_ok=True)
DB_FILE.parent.mkdir(exist_ok=True)

# Valores cargados del .env con fallbacks por defecto
API_PORT = int(os.getenv("API_PORT", 5000))
RF_PORT = os.getenv("RF_PORT", "/dev/ttyUSB0")
RF_BAUD = int(os.getenv("RF_BAUD", 9600))
