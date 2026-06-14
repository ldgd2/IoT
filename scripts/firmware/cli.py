import rich_click as click
import subprocess
import os
from pathlib import Path
from rich.console import Console
from rich.panel import Panel
import questionary
import serial.tools.list_ports

console = Console()
ROOT_DIR = Path(__file__).parent.parent.parent.resolve()

def check_pio():
    """Verifica si PlatformIO está instalado"""
    try:
        subprocess.run(["pio", "--version"], capture_output=True, check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False

@click.group()
def firmware():
    """Gestión y Compilación de Firmware C++ (PlatformIO)"""
    pass

@firmware.command(name="wizard")
def firmware_wizard():
    """Asistente interactivo de compilación y flasheo de firmware"""
    console.print(Panel.fit("[bold cyan]🔨 Asistente de Compilación y Flasheo de Firmware[/bold cyan]", border_style="cyan"))
    
    if not check_pio():
        console.print("[red]❌ Error: PlatformIO Core (pio) no está instalado o no está en el PATH.[/red]")
        console.print("[yellow]Instálalo usando: pip install platformio[/yellow]")
        return
        
    # 1. Seleccionar la placa
    placa = questionary.select(
        "¿Para qué placa de desarrollo deseas compilar?",
        choices=[
            "YD-RP2040 (Raspberry Pi Pico)",
            "ESP8266",
            "ESP32",
            "Arduino (Nano/Uno)"
        ]
    ).ask()
    if not placa: return
    
    env_map = {
        "YD-RP2040 (Raspberry Pi Pico)": "rp2040",
        "ESP8266": "esp8266",
        "ESP32": "esp32",
        "Arduino (Nano/Uno)": "arduino_nano"
    }
    pio_env = env_map[placa]

    # 2. Seleccionar dispositivos
    device_choice = questionary.select(
        "¿Qué firmware de dispositivo deseas compilar?",
        choices=[
            "Solo Luces (lights)",
            "Solo Traductor Gateway (translator)",
            "COMPILAR TODOS LOS DISPOSITIVOS"
        ]
    ).ask()
    if not device_choice: return
    
    if "TODOS" in device_choice:
        targets = ["lights", "translator"]
    elif "Luces" in device_choice:
        targets = ["lights"]
    else:
        targets = ["translator"]

    # 3. Flujo condicional por Placa
    if pio_env == "rp2040":
        import shutil
        out_dir = ROOT_DIR / "firmwareCompiled" / "device"
        
        # Solo compilar para RP2040 y mover el UF2
        for t in targets:
            console.print(f"\n[bold yellow]🛠️  Compilando {t} para {placa}...[/bold yellow]")
            proj_dir = ROOT_DIR / "devices" / t
            res = subprocess.run(["pio", "run", "-e", pio_env], cwd=proj_dir)
            if res.returncode == 0:
                uf2_source = proj_dir / ".pio" / "build" / pio_env / "firmware.uf2"
                dest_folder = out_dir / t
                dest_folder.mkdir(parents=True, exist_ok=True)
                dest_file = dest_folder / f"firmware_{t}.uf2"
                
                if uf2_source.exists():
                    shutil.copy2(uf2_source, dest_file)
                    console.print(f"[green]✅ Compilación exitosa para {t}.[/green]")
                    console.print(f"[bold cyan]📁 Archivo UF2 exportado a: {dest_file}[/bold cyan]")
                else:
                    console.print(f"[red]❌ Error: Compilación exitosa pero no se encontró el archivo {uf2_source}[/red]")
            else:
                console.print(f"[red]❌ Error compilando {t}[/red]")
                
    else:
        # ESP/Arduino requieren seleccionar puerto COM
        ports = serial.tools.list_ports.comports()
        if not ports:
            console.print("[red]❌ No se detectaron puertos COM conectados. Conecta tu placa e intenta de nuevo.[/red]")
            return
            
        port_choices = [f"{p.device} - {p.description}" for p in ports]
        
        for t in targets:
            console.print(f"\n[bold magenta]👉 Dispositivo actual: {t.upper()}[/bold magenta]")
            port_selection = questionary.select(
                f"Selecciona el puerto COM donde está conectado el {t}:",
                choices=port_choices
            ).ask()
            if not port_selection: return
            
            com_port = port_selection.split(" - ")[0]
            
            console.print(f"[bold yellow]🛠️  Compilando y subiendo {t} a {com_port}...[/bold yellow]")
            proj_dir = ROOT_DIR / "devices" / t
            
            res = subprocess.run(["pio", "run", "-t", "upload", "--upload-port", com_port, "-e", pio_env], cwd=proj_dir)
            
            if res.returncode == 0:
                console.print(f"[green]✅ Firmware subido exitosamente a {t} en {com_port}[/green]")
            else:
                console.print(f"[red]❌ Error al subir a {t}[/red]")
