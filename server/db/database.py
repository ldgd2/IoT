# =============================================================
# server/db/database.py
# Base de datos SQLite propia del Servidor (Arquitectura Multi-Hub)
# =============================================================
import sqlite3
import os
from pathlib import Path

SERVER_DIR = Path(__file__).parent.parent.resolve()
DB_FILE = SERVER_DIR / "db" / "server.sqlite"
DB_FILE.parent.mkdir(exist_ok=True)


def get_connection():
    conn = sqlite3.connect(str(DB_FILE))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def execute(query: str, params: tuple = ()):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(query, params)
        conn.commit()
        return cur


def ensure_tables():
    """Crea todas las tablas del servidor si no existen."""
    # 1. users
    execute("""
        CREATE TABLE IF NOT EXISTS users (
            user_id       TEXT PRIMARY KEY,
            username      TEXT NOT NULL,
            email         TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            fcm_token     TEXT DEFAULT '',
            created_at    TEXT NOT NULL
        )
    """)
    # 2. hubs
    execute("""
        CREATE TABLE IF NOT EXISTS hubs (
            hub_id        TEXT PRIMARY KEY,
            user_id       TEXT NOT NULL,
            name          TEXT NOT NULL,
            local_url     TEXT,
            relay_secret  TEXT,
            last_seen     TEXT,
            online        INTEGER DEFAULT 0,
            created_at    TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        )
    """)
    # 3. spaces (antes rooms)
    execute("""
        CREATE TABLE IF NOT EXISTS spaces (
            space_id      TEXT PRIMARY KEY,
            hub_id        TEXT NOT NULL,
            name          TEXT NOT NULL,
            icon          TEXT DEFAULT 'home',
            created_at    TEXT NOT NULL,
            FOREIGN KEY (hub_id) REFERENCES hubs(hub_id)
        )
    """)
    # 4. devices
    execute("""
        CREATE TABLE IF NOT EXISTS devices (
            device_id     TEXT PRIMARY KEY,
            hub_id        TEXT NOT NULL,
            space_id      TEXT,
            alias         TEXT DEFAULT '',
            created_at    TEXT NOT NULL,
            FOREIGN KEY (hub_id) REFERENCES hubs(hub_id),
            FOREIGN KEY (space_id) REFERENCES spaces(space_id)
        )
    """)
    # 5. notifications
    execute("""
        CREATE TABLE IF NOT EXISTS notifications (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id       TEXT NOT NULL,
            hub_id        TEXT DEFAULT '',
            device_id     TEXT DEFAULT '',
            title         TEXT NOT NULL,
            body          TEXT DEFAULT '',
            event_type    TEXT DEFAULT 'info',
            read          INTEGER DEFAULT 0,
            created_at    TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        )
    """)
    print("[SERVER DB] Tablas de la arquitectura Multi-Hub verificadas/creadas.")
