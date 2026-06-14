"""
rf_gateway.py — Stub del driver de radiofrecuencia
Reemplazar con el driver real según hardware:
  - RF433 (OOK/ASK)  →  usar pyserial con Arduino transmisor
  - nRF24L01+         →  usar pyrf24 o RF24 library
  - LoRa SX127x       →  usar adafruit-circuitpython-rfm9x o SX127x lib
  - Serial bridge     →  Arduino/ESP32 como gateway, leer por UART

Este módulo publica mensajes al servidor Flask vía HTTP local.
"""

import serial
import json
import time
import requests
import socket
import threading
from datetime import datetime

def get_local_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"

SERIAL_PORT = "/dev/ttyUSB0"   # Cambiar según puerto
BAUD_RATE   = 9600
SERVER_URL  = f"http://{get_local_ip()}:5000/api/ingest"


def parse_rf_line(raw: str) -> dict | None:
    """
    Parsea una línea de texto del módulo RF/Arduino.
    Protocolo mínimo esperado:
      JSON: {"id":"dev_001","rssi":-72,"payload":{"on":true}}
    """
    raw = raw.strip()
    if not raw or raw.startswith("#"):   # comentarios
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # Protocolo simple CSV: id,rssi,key=val,...
        parts = raw.split(",")
        if len(parts) >= 2:
            return {
                "id": parts[0].strip(),
                "rssi": int(parts[1].strip()) if parts[1].strip().lstrip("-").isdigit() else None,
                "payload": {"raw": raw},
            }
    return None


def send_to_server(data: dict):
    try:
        r = requests.post(SERVER_URL, json=data, timeout=2)
        return r.ok
    except Exception as e:
        print(f"[RF] Error enviando a servidor: {e}")
        return False


def serial_loop():
    while True:
        try:
            with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1) as ser:
                print(f"[RF] Puerto {SERIAL_PORT} abierto a {BAUD_RATE} baud")
                while True:
                    line = ser.readline().decode("utf-8", errors="ignore")
                    if line:
                        data = parse_rf_line(line)
                        if data:
                            print(f"[RF] RX: {data}")
                            send_to_server(data)
        except serial.SerialException as e:
            print(f"[RF] Puerto serial no disponible: {e} — reintentando en 5s")
            time.sleep(5)
        except Exception as e:
            print(f"[RF] Error: {e}")
            time.sleep(2)


if __name__ == "__main__":
    print("[RF] Iniciando gateway de radiofrecuencia...")
    serial_loop()
