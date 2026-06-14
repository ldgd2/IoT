import os
from pathlib import Path

ROOT_DIR = Path(__file__).parent.parent.resolve()
SERVER_DIR = ROOT_DIR / "server"
LOG_DIR = ROOT_DIR / "logs"
DB_FILE = SERVER_DIR / "db" / "data.sqlite"
PID_FILE = ROOT_DIR / ".server.pid"
VENV_DIR = ROOT_DIR / ".venv"

LOG_DIR.mkdir(exist_ok=True)
DB_FILE.parent.mkdir(exist_ok=True)
