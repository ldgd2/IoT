#!/usr/bin/env python3
# ==============================================================================
# pair_device.py — Activador de Emparejamiento por Serial USB para Nodos Colmena
# ==============================================================================
# Envía el comando "PAIR" al puerto serial COM/USB de un nodo (luz, enchufe, sensor)
# para que el microcontrolador se anuncie (CMD_DISCOVER) a la red RF24Mesh sin botón.
# ==============================================================================

import sys
import time
import argparse
from pathlib import Path

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("❌ Error: Falta la librería pyserial. Instálala con: pip install pyserial")
    sys.exit(1)

# Intentar usar colores de rich si están disponibles
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
    console = Console()
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

def print_msg(msg, style="bold cyan"):
    if RICH_AVAILABLE:
        console.print(f"[{style}]{msg}[/{style}]")
    else:
        print(msg)

def list_available_ports():
    ports = list(serial.tools.list_ports.comports())
    return ports

def auto_select_port():
    ports = list_available_ports()
    if not ports:
        print_msg("⚠️ No se encontraron puertos seriales / COM conectados.", "bold red")
        return None
    
    if len(ports) == 1:
        print_msg(f"🔍 Puerto detectado automáticamente: {ports[0].device} ({ports[0].description})", "bold green")
        return ports[0].device

    if RICH_AVAILABLE:
        table = Table(title="🔌 Puertos Seriales Disponibles")
        table.add_column("#", style="cyan", justify="right")
        table.add_column("Puerto", style="green bold")
        table.add_column("Descripción / Hardware", style="yellow")
        for idx, p in enumerate(ports, 1):
            table.add_row(str(idx), p.device, f"{p.description} ({p.hwid})")
        console.print(table)
    else:
        print("\n--- Puertos Disponibles ---")
        for idx, p in enumerate(ports, 1):
            print(f"  [{idx}] {p.device} -> {p.description}")
        print("---------------------------")

    while True:
        try:
            sel = input("\n👉 Selecciona el número del puerto del dispositivo: ").strip()
            if not sel:
                continue
            idx = int(sel) - 1
            if 0 <= idx < len(ports):
                return ports[idx].device
            else:
                print("❌ Número fuera de rango.")
        except (ValueError, IndexError):
            print("❌ Entrada inválida. Ingresa un número.")
        except KeyboardInterrupt:
            print("\nOperación cancelada.")
            sys.exit(0)

def trigger_pairing(port, baudrate=115200):
    print_msg(f"\n📡 Conectando a {port} a {baudrate} baudios...", "bold blue")
    try:
        with serial.Serial(port, baudrate, timeout=2.0) as ser:
            time.sleep(1.8) # Esperar a que el microcontrolador (Arduino/RP2040) reinicie el puerto
            ser.reset_input_buffer()

            # 1. Solicitar estado
            print_msg("📤 Consultando estado del nodo...", "dim")
            ser.write(b"STATUS\r\n")
            ser.flush()
            time.sleep(0.3)
            while ser.in_waiting:
                line = ser.readline().decode("utf-8", errors="replace").strip()
                if line:
                    print_msg(f"   [NODO] {line}", "green")

            # 2. Enviar señal de emparejamiento (PAIR)
            print_msg("⚡ Enviando comando de vinculación vía USB Serial ('PAIR')...", "bold yellow")
            ser.write(b"PAIR\r\n")
            ser.flush()
            
            # 3. Escuchar respuesta y confirmación de transmisión por RF
            start_time = time.time()
            received_response = False
            while time.time() - start_time < 3.0:
                if ser.in_waiting:
                    line = ser.readline().decode("utf-8", errors="replace").strip()
                    if line:
                        print_msg(f"   [RESPUESTA] {line}", "bold green" if "Anuncio" in line or "✔️" in line else "cyan")
                        received_response = True
                time.sleep(0.05)

            if received_response:
                print_msg("\n🎉 ¡Señal de emparejamiento procesada! El nodo se ha anunciado al Gateway Hub.", "bold green")
                print_msg("📱 Revisa tu aplicación Flutter o la base de datos para confirmar la vinculación.", "bold cyan")
            else:
                print_msg("\n⚠️ No se recibió respuesta textual, pero el comando fue enviado al puerto.", "yellow")

    except serial.SerialException as e:
        print_msg(f"❌ Error abriendo el puerto {port}: {e}", "bold red")
        print_msg("💡 Asegúrate de no tener el monitor serial abierto en otro programa.", "dim")

def main():
    parser = argparse.ArgumentParser(description="Disparador de Emparejamiento por Serial para Dispositivos Colmena")
    parser.add_argument("-p", "--port", help="Puerto COM o /dev/ttyACM0 del dispositivo a emparejar")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Velocidad en baudios (default: 115200)")
    parser.add_argument("--list", action="store_true", help="Listar puertos disponibles y salir")
    parser.add_argument("--cli", action="store_true", help="Ejecutar en modo terminal de texto en lugar de GUI Qt6")
    args = parser.parse_args()

    # Si no se pide explícitamente CLI, abrir la interfaz gráfica Qt6 modular
    if not args.cli and not args.list and not args.port:
        try:
            from test_serial import TestSerial
            TestSerial.run()
            return
        except ImportError as e:
            print(f"⚠️ No se pudo iniciar GUI Qt6 ({e}). Pasando a modo terminal...\n")

    if RICH_AVAILABLE:
        console.print(Panel.fit("[bold magenta]✨ Colmena Pair Tool — Emparejamiento por USB Serial[/bold magenta]", border_style="magenta"))

    if args.list:
        auto_select_port()
        return

    port = args.port
    if not port:
        port = auto_select_port()

    if port:
        trigger_pairing(port, args.baud)

if __name__ == "__main__":
    main()
