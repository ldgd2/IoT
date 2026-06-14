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
    
    # Formato de la estructura C++: < (Little-Endian), 4 bytes unsigned char, 4 ints unsigned de 32 bits
    # uint8_t originId;
    # uint8_t destId;
    # uint8_t deviceType;
    # uint8_t command;
    # uint32_t data[4];
    STRUCT_FORMAT = '<BBBBIIII'
    STRUCT_SIZE = struct.calcsize(STRUCT_FORMAT) # Debe ser 20 bytes

    def __init__(self, port_override=None):
        self.port_string = port_override or os.getenv("RF_PORT")
        self.mode = "NONE"
        self.hid_device = None
        self.serial_device = None
        self.is_connected = False
        self.listener_thread = None
        self._stop_event = threading.Event()
        self.on_packet_received = None # Callback para eventos entrantes

    def connect(self):
        if not self.port_string:
            console.print("[red]No se ha configurado RF_PORT en el .env[/red]")
            return False
            
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

    def send_command(self, dest_id: int, command: int, device_type: int = 0, data: list = None):
        """
        Envia un comando atomico a un dispositivo de la colmena.
        """
        if not self.is_connected:
            console.print("[yellow]Advertencia: Intentando enviar datos sin conexion.[/yellow]")
            return False
            
        if data is None:
            data = [0, 0, 0, 0]
        
        # Rellenar ceros si la lista es corta
        while len(data) < 4:
            data.append(0)
            
        if self.mode == "HID":
            # Empaquetar bytes usando Struct para C++
            binary_packet = struct.pack(self.STRUCT_FORMAT, 0, dest_id, device_type, command, *data[:4])
            
            # El reporte HID es de 64 bytes, rellenamos el resto con ceros
            # El primer byte de HID out report id a veces requiere ser 0x00
            report = bytearray(65)
            report[0] = 0x00 # Report ID
            report[1:1+len(binary_packet)] = binary_packet
            
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
                "data": data[:4]
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
                    if data:
                        # Si es un ACK del traductor, el primer byte es 1 o 0
                        # Pero si es un paquete crudo (>= 20 bytes), lo parseamos
                        if len(data) >= self.STRUCT_SIZE:
                            unpacked = struct.unpack(self.STRUCT_FORMAT, bytes(data[:self.STRUCT_SIZE]))
                            origin, dest, dev_type, cmd, d1, d2, d3, d4 = unpacked
                            packet_dict = {
                                "origin": origin,
                                "dest": dest,
                                "type": dev_type,
                                "cmd": cmd,
                                "data": [d1, d2, d3, d4]
                            }
                            if self.on_packet_received:
                                self.on_packet_received(packet_dict)
                except Exception:
                    pass
                    
            elif self.mode == "SERIAL":
                try:
                    if self.serial_device.in_waiting > 0:
                        line = self.serial_device.readline().decode('utf-8').strip()
                        if line.startswith("{") and line.endswith("}"):
                            try:
                                packet_dict = json.loads(line)
                                if self.on_packet_received:
                                    self.on_packet_received(packet_dict)
                            except json.JSONDecodeError:
                                pass
                except Exception:
                    pass
                    
            time.sleep(0.01) # Prevenir uso de 100% CPU
