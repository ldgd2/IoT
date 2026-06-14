# IoT RF Gateway

Backend ultra-liviano para control de dispositivos IoT via **radiofrecuencia** (RF433 / nRF24L01+ / LoRa).
Diseñado para correr en hardware de mínimos recursos: Raspberry Pi, Orange Pi, laptops viejas, cualquier cosa con Python 3.

---

## Estructura

```
IoT/
├── server/
│   ├── app.py              # Servidor Flask principal
│   ├── rf_gateway.py       # Driver RF (puente serial → HTTP)
│   ├── requirements.txt
│   └── templates/
│       ├── base.html       # Design system compartido
│       ├── dashboard.html  # Panel principal de dispositivos
│       ├── device.html     # Detalle y control de un dispositivo
│       └── log.html        # Log de mensajes RF
└── luces/                  # Firmware / clientes de dispositivos
```

## Levantar el servidor

```bash
cd server
pip install -r requirements.txt
python app.py
# → http://0.0.0.0:5000
```

## API REST

| Método | Endpoint              | Descripción                        |
|--------|-----------------------|------------------------------------|
| GET    | `/`                   | Dashboard HTML                     |
| GET    | `/device/<id>`        | Detalle de dispositivo             |
| GET    | `/log`                | Log RF HTML                        |
| GET    | `/api/devices`        | Lista de dispositivos (JSON)       |
| GET    | `/api/device/<id>`    | Estado de un dispositivo (JSON)    |
| POST   | `/api/ingest`         | Recibe trama RF desde gateway      |
| POST   | `/api/command`        | Envía comando a un dispositivo     |
| GET    | `/api/stats`          | Estadísticas del servidor          |

### Payload de ingesta (RF → Servidor)
```json
{
  "id": "dev_001",
  "name": "Luz Sala",
  "type": "light",
  "rssi": -72,
  "payload": { "on": true, "brightness": 80 }
}
```

### Payload de comando (Servidor → RF)
```json
{
  "id": "dev_001",
  "cmd": "set",
  "params": { "on": false }
}
```

## Módulos RF soportados

- **RF433 / ASK** → Arduino como transmisor serial, leer por UART
- **nRF24L01+** → `pyrf24` library en Raspberry Pi
- **LoRa SX127x** → `adafruit-circuitpython-rfm9x`
- **ESP32/ESP8266** → Bridge WiFi↔RF, POST a `/api/ingest`
