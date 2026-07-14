import os
import struct
import json
import threading
import time
from dotenv import load_dotenv

# Dependencias opcionales de hardware
try:
    import hid
except ImportError:
    hid = None

try:
    import serial
except ImportError:
    serial = None

from rich.console import Console

console = Console()
load_dotenv()

class IoTGateway:
    """
    Clase unificada para interactuar con la Colmena IoT.
    Abstrae la complejidad de si la conexion es HID Nativa (RP2040)
    o Serial COM (ESP8266/ESP32).
    """
    
    # Formato de la estructura C++: < (Little-Endian), 4 bytes unsigned char, 26 bytes array, 1 unsigned short (checksum)
    # uint8_t originId;
    # uint8_t destId;
    # uint8_t deviceType;
    # uint8_t command;
    # uint8_t data[26];
    # uint16_t checksum;
    STRUCT_FORMAT = '<BBBB26sH'
    STRUCT_SIZE = struct.calcsize(STRUCT_FORMAT) # 32 bytes

    def __init__(self, port_override=None):
        self.port_string = port_override or os.getenv("RF_PORT")
        self.mode = "NONE"
        self.hid_device = None
        self.serial_device = None
        self.is_connected = False
        self.listener_thread = None
        self._stop_event = threading.Event()
        self.on_packet_received = None # Callback para eventos entrantes
        self.last_tx = "Ninguno"
        self.last_rx = "Ninguno"
        self.pairing_status = "idle"
        self.pairing_start_time = 0
        self.last_paired_device = None

    def connect(self):
        if not self.port_string:
            console.print("[red]No se ha configurado RF_PORT en el .env[/red]")
            return False

        # Limpiar comillas que python-dotenv puede dejar si el .env tiene RF_PORT='valor'
        self.port_string = self.port_string.strip("'\"")

        # Normalizar formato legado: HID_VVVV:PPPP → HID:VVVV:PPPP
        if self.port_string.startswith("HID_"):
            self.port_string = "HID:" + self.port_string[4:]

        if self.port_string.startswith("HID:"):
            return self._connect_hid()
        else:
            return self._connect_serial()

    def _connect_hid(self):
        if not hid:
            console.print("[red]Libreria 'hidapi' no instalada. Usa 'pip install hidapi'.[/red]")
            return False
            
        parts = self.port_string.split(":")
        if len(parts) != 3:
            console.print("[red]Formato HID invalido. Debe ser HID:VID:PID[/red]")
            return False
            
        try:
            vid = int(parts[1], 16)
            pid = int(parts[2], 16)
            self.hid_device = hid.device()
            self.hid_device.open(vid, pid)
            self.hid_device.set_nonblocking(1) # Leer sin bloquear todo el hilo
            self.mode = "HID"
            self.is_connected = True
            console.print(f"[green]Conectado a Traductor USB HID (VID:{vid:04x} PID:{pid:04x})[/green]")
            return True
        except Exception as e:
            console.print(f"[red]Error abriendo dispositivo HID: {e}[/red]")
            return False

    def _connect_serial(self):
        if not serial:
            console.print("[red]Libreria 'pyserial' no instalada.[/red]")
            return False
            
        try:
            # pyserial espera el nombre del puerto ej. COM3 o /dev/ttyUSB0
            self.serial_device = serial.Serial(self.port_string, 115200, timeout=1)
            self.mode = "SERIAL"
            self.is_connected = True
            console.print(f"[green]Conectado a Traductor Serial ({self.port_string}) a 115200 baudios[/green]")
            return True
        except Exception as e:
            console.print(f"[red]Error abriendo puerto Serial: {e}[/red]")
            return False

    def calc_checksum(self, packet_bytes_30: bytes) -> int:
        crc = 0xFFFF
        for b in packet_bytes_30:
            crc ^= (b << 8)
            for _ in range(8):
                if crc & 0x8000:
                    crc = ((crc << 1) ^ 0x1021) & 0xFFFF
                else:
                    crc = (crc << 1) & 0xFFFF
        return crc

    def send_command(self, dest_id: int, command: int, device_type: int = 0, data: list = None):
        """
        Envia un comando atomico a un dispositivo de la colmena.
        """
        if not self.is_connected:
            console.print("[yellow]Advertencia: Intentando enviar datos sin conexion.[/yellow]")
            return False
            
        if command == 0x0D:
            self.pairing_status = "active"
            self.pairing_start_time = time.time()
            self.last_paired_device = None
            self.last_tx = "CMD_PAIR_START (Buscando nodos por 50s)..."
            self.last_rx = "Esperando anuncio del nodo..."
        elif command == 0x0E:
            self.pairing_status = "idle"
            self.last_tx = "CMD_PAIR_STOP (Vinculación detenida)"
        else:
            cmd_names = {1: "PING", 2: "REPORT", 3: "SYNC", 4: "HEARTBEAT", 5: "DISCOVER", 6: "CONTROL"}
            c_name = cmd_names.get(command, f"0x{command:02X}")
            self.last_tx = f"ID {dest_id} | CMD: {c_name}"

        if data is None:
            data = [0, 0, 0, 0]
        
        # Rellenar ceros si la lista es corta
        while len(data) < 4:
            data.append(0)
            
        if self.mode == "HID":
            # Empaquetar bytes usando Struct para C++
            # Empaquetamos los primeros 26 bytes de data
            data_bytes = bytes(data[:26] + [0]*(26-len(data)))
            header_body = struct.pack('<BBBB26s', 0, dest_id, device_type, command, data_bytes)
            chk = self.calc_checksum(header_body)
            binary_packet = struct.pack(self.STRUCT_FORMAT, 0, dest_id, device_type, command, data_bytes, chk)
            
            # El reporte HID es de 64 bytes, rellenamos el resto con ceros
            # El primer byte de HID out report id a veces requiere ser 0x00
            report = bytearray(65)
            report[0] = 0x00 # Report ID
            report[1:1+self.STRUCT_SIZE] = binary_packet
            
            try:
                self.hid_device.write(report)
                return True
            except Exception as e:
                console.print(f"[red]Error enviando HID: {e}[/red]")
                return False
                
        elif self.mode == "SERIAL":
            # Empaquetar como JSON para el ESP8266
            payload = {
                "dest": dest_id,
                "cmd": command,
                "data": data[:26]
            }
            try:
                json_str = json.dumps(payload) + "\n"
                self.serial_device.write(json_str.encode('utf-8'))
                return True
            except Exception as e:
                console.print(f"[red]Error enviando Serial: {e}[/red]")
                return False

    def start_listening(self):
        """ Inicia el hilo en segundo plano para escuchar a la colmena """
        if not self.is_connected:
            return
            
        self._stop_event.clear()
        self.listener_thread = threading.Thread(target=self._listen_loop, daemon=True)
        self.listener_thread.start()
        
    def stop_listening(self):
        self._stop_event.set()
        if self.listener_thread:
            self.listener_thread.join(timeout=2)
            
    def _listen_loop(self):
        while not self._stop_event.is_set():
            if self.mode == "HID":
                try:
                    # Leer 64 bytes no bloqueante
                    data = self.hid_device.read(64)
                    if data and len(data) >= 33:
                        flag = data[32]
                        if flag == 0x01: # Paquete RF válido entrante
                            unpacked = struct.unpack(self.STRUCT_FORMAT, bytes(data[:self.STRUCT_SIZE]))
                            origin, dest, dev_type, cmd, data_bytes, checksum = unpacked
                            cmd_names = {1: "PING", 2: "REPORT", 3: "SYNC", 4: "HEARTBEAT", 5: "DISCOVER", 6: "CONTROL", 13: "PAIR_START", 14: "PAIR_STOP"}
                            cmd_str = cmd_names.get(cmd, f"0x{cmd:02X}")
                            self.last_rx = f"ID {origin} ➔ Gateway | CMD: {cmd_str}"
                            if cmd == 5:
                                was_pairing_active = (self.pairing_status == "active")
                                self.pairing_status = "success"
                                self.last_paired_device = {"id": f"dev_{origin}", "origin": origin}
                                try:
                                    # 0x07 = CMD_CONFIG_SYNC: [rfChannel=76, rfDataRate=0, heartbeat=15, 'C','o','l','m','e']
                                    self.send_command(dest_id=origin, command=0x07, device_type=dev_type, data=[76, 0, 15, 67, 111, 108, 109, 101])
                                except Exception:
                                    pass
                            else:
                                was_pairing_active = (self.pairing_status == "active")
                            packet_dict = {
                                "origin": origin,
                                "dest": dest,
                                "type": dev_type,
                                "cmd": cmd,
                                "data": list(data_bytes),
                                "was_pairing_active": was_pairing_active
                            }
                            if self.on_packet_received:
                                self.on_packet_received(packet_dict)
                        elif flag == 0x03: # Status / Evento JSON o texto desde el Traductor
                            try:
                                part1 = bytes(data[:32]).rstrip(b'\x00')
                                part2 = bytes(data[33:64]).rstrip(b'\x00')
                                text = (part1 + part2).decode('utf-8', errors='ignore')
                                if not hasattr(self, '_rx_json_buf'): self._rx_json_buf = ""
                                if text.startswith("{") and text.endswith("}"):
                                    self._rx_json_buf = ""
                                    text_to_parse = text
                                elif text.startswith("{"):
                                    self._rx_json_buf = text
                                    text_to_parse = None
                                elif self._rx_json_buf:
                                    self._rx_json_buf += text
                                    text_to_parse = self._rx_json_buf if self._rx_json_buf.endswith("}") else None
                                else:
                                    text_to_parse = None

                                if text_to_parse and text_to_parse.startswith("{") and text_to_parse.endswith("}"):
                                    self._rx_json_buf = ""
                                    event_dict = json.loads(text_to_parse)
                                    if event_dict.get("event") == "pairing_timeout":
                                        self.pairing_status = "timeout"
                                        self.last_rx = "TIMEOUT: El traductor reporta ventana agotada (50s)"
                                    elif event_dict.get("event") == "pairing_success":
                                        event_dict["was_pairing_active"] = (self.pairing_status == "active") or True
                                        self.pairing_status = "success"
                                        self.last_rx = "EXITO: Nuevo nodo emparejado con el traductor"
                                        node_id = event_dict.get("nodeId") or event_dict.get("origin")
                                        if node_id:
                                            self.last_paired_device = {
                                                "id": f"dev_{node_id}",
                                                "origin": node_id,
                                                "name": event_dict.get("name", f"Nodo {node_id}"),
                                                "type": event_dict.get("type", 1),
                                                "features": event_dict.get("features", 1)
                                            }
                                            try:
                                                self.send_command(dest_id=int(node_id), command=0x07, device_type=0, data=[76, 0, 15, 67, 111, 108, 109, 101])
                                            except Exception:
                                                pass
                                        if self.on_packet_received:
                                            self.on_packet_received(event_dict)
                            except Exception:
                                pass
                except Exception:
                    pass
                    
            elif self.mode == "SERIAL":
                try:
                    if self.serial_device.in_waiting > 0:
                        line = self.serial_device.readline().decode('utf-8').strip()
                        if line.startswith("{") and line.endswith("}"):
                            try:
                                packet_dict = json.loads(line)
                                if "log" in packet_dict and isinstance(packet_dict["log"], str) and packet_dict["log"].startswith("{") and packet_dict["log"].endswith("}"):
                                    try: packet_dict = json.loads(packet_dict["log"])
                                    except Exception: pass

                                if packet_dict.get("event") == "pairing_timeout":
                                    self.pairing_status = "timeout"
                                    self.last_rx = "TIMEOUT: El traductor reporta ventana agotada (50s)"
                                elif packet_dict.get("event") == "pairing_success":
                                    packet_dict["was_pairing_active"] = (self.pairing_status == "active") or True
                                    self.pairing_status = "success"
                                    self.last_rx = "EXITO: Nuevo nodo emparejado con el traductor"
                                    node_id = packet_dict.get("nodeId") or packet_dict.get("origin")
                                    if node_id:
                                        self.last_paired_device = {
                                            "id": f"dev_{node_id}",
                                            "origin": node_id,
                                            "name": packet_dict.get("name", f"Nodo {node_id}"),
                                            "type": packet_dict.get("type", 1),
                                            "features": packet_dict.get("features", 1)
                                        }
                                    if self.on_packet_received:
                                        self.on_packet_received(packet_dict)
                                elif "cmd" in packet_dict and "origin" in packet_dict:
                                    cmd = packet_dict["cmd"]
                                    origin = packet_dict["origin"]
                                    cmd_names = {1: "PING", 2: "REPORT", 3: "SYNC", 4: "HEARTBEAT", 5: "DISCOVER", 6: "CONTROL"}
                                    cmd_str = cmd_names.get(cmd, f"0x{cmd:02X}")
                                    self.last_rx = f"ID {origin} -> Gateway | CMD: {cmd_str}"
                                    if cmd == 5:
                                        packet_dict["was_pairing_active"] = (self.pairing_status == "active")
                                        self.pairing_status = "success"
                                        self.last_paired_device = {"id": f"dev_{origin}", "origin": origin}
                                    else:
                                        packet_dict["was_pairing_active"] = (self.pairing_status == "active")
                                    if self.on_packet_received: self.on_packet_received(packet_dict)
                                elif self.on_packet_received:
                                    self.on_packet_received(packet_dict)
                            except json.JSONDecodeError:
                                pass
                except Exception:
                    pass
                    
            if self.pairing_status == "active" and self.pairing_start_time > 0:
                if time.time() - self.pairing_start_time > 52:
                    self.pairing_status = "timeout"
                    self.last_rx = "TIMEOUT: Ventana de vinculación vencida (50s)"
                    
            time.sleep(0.01) # Prevenir uso de 100% CPU

# Instancia global para ser usada en todo el servidor
gateway = IoTGateway()
