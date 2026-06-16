import rich_click as click
import questionary
from rich.console import Console
from rich.panel import Panel
from hub.core.config import ENV_FILE, VENV_DIR
from dotenv import dotenv_values
import os
import subprocess
import sys
import serial.tools.list_ports
import hid

console = Console()

@click.group()
def setup():
    """Asistente de configuración del entorno (.env)"""
    pass

@setup.command(name="env")
def setup_env():
    """Abre el asistente interactivo para crear/editar el archivo .env"""
    console.print(Panel.fit("[bold cyan]⚙️  Asistente de Configuración (.env)[/bold cyan]", border_style="cyan"))
    
    current_env = {}
    if ENV_FILE.exists():
        console.print(f"[yellow]Archivo .env detectado en {ENV_FILE}[/yellow]")
        current_env = dotenv_values(ENV_FILE)
    else:
        console.print("[yellow]No se encontró archivo .env. Se creará uno nuevo.[/yellow]")
    
    console.print("[dim]Presiona Enter para mantener el valor actual o escribe uno nuevo.[/dim]\n")
    
    # Preguntar valores interactivos usando questionary
    api_port = questionary.text(
        "Puerto del API (API_PORT):",
        default=current_env.get("API_PORT", "5000")
    ).ask()
    if not api_port: return
    
    rf_baud = questionary.text(
        "Baudrate (solo aplica si usas Serial/COM):",
        default=current_env.get("RF_BAUD", "115200")
    ).ask()
    if not rf_baud: return
    
    conn_type = questionary.select(
        "¿Qué tipo de conexión utiliza el Traductor Gateway?",
        choices=[
            "1. Conexión USB HID Nativa (Recomendado para YD-RP2040 / Raspberry Pico)",
            "2. Conexión Serial COM (Recomendado para ESP8266 / ESP32 / Arduino)"
        ]
    ).ask()
    if not conn_type: return

    rf_port = ""
    if "HID" in conn_type:
        console.print("[dim]Buscando dispositivos USB HID conectados...[/dim]")
        devices = hid.enumerate()
        # Filtrar duplicados por VID:PID
        unique_hids = {}
        for d in devices:
            key = f"HID:{d['vendor_id']:04x}:{d['product_id']:04x}"
            if key not in unique_hids:
                unique_hids[key] = f"{key} - {d.get('manufacturer_string', 'Unknown')} {d.get('product_string', 'Unknown')}"
        
        hid_choices = list(unique_hids.values())
        if not hid_choices:
            console.print("[red]❌ No se detectaron dispositivos USB HID. Conecta tu RP2040.[/red]")
            return
            
        selected_hid = questionary.select("Selecciona el dispositivo Traductor HID:", choices=hid_choices).ask()
        if not selected_hid: return
        rf_port = selected_hid.split(" - ")[0]
    else:
        console.print("[dim]Buscando puertos COM conectados...[/dim]")
        ports = serial.tools.list_ports.comports()
        com_choices = [f"{p.device} - {p.description}" for p in ports]
        if not com_choices:
            console.print("[red]❌ No se detectaron puertos COM. Conecta tu Arduino/ESP.[/red]")
            return
            
        selected_com = questionary.select("Selecciona el puerto COM del Traductor:", choices=com_choices).ask()
        if not selected_com: return
        rf_port = selected_com.split(" - ")[0]
    
    # Confirmar escritura
    if not questionary.confirm("¿Guardar esta configuración en el archivo .env?").ask():
        console.print("[red]Configuración cancelada.[/red]")
        return
        
    with open(ENV_FILE, "w") as f:
        f.write(f"API_PORT={api_port}\n")
        f.write(f"RF_PORT={rf_port}\n")
        f.write(f"RF_BAUD={rf_baud}\n")
        
    console.print(f"\n[bold green]✅ Configuración guardada exitosamente en {ENV_FILE}[/bold green]")

@setup.command(name="install-deps")
def install_deps():
    """Crea el entorno virtual e instala todas las dependencias"""
    console.print(Panel.fit("[bold cyan]🛠️  Instalación de Entorno Virtual y Dependencias[/bold cyan]", border_style="cyan"))
    
    # 1. Crear VENV
    if not VENV_DIR.exists():
        console.print("[yellow]Creando entorno virtual (.venv)...[/yellow]")
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)])
    else:
        console.print("[green]✅ Entorno virtual (.venv) ya existe.[/green]")

    # Determinar ejecutable de Python dentro del VENV
    py_exec = str(VENV_DIR / "bin" / "python")
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe")
        
    if not os.path.exists(py_exec):
        console.print("[red]❌ Error crítico: No se encontró el ejecutable de Python en el entorno virtual.[/red]")
        return

    # 2. Actualizar pip
    console.print("\n[yellow]Actualizando pip...[/yellow]")
    subprocess.run([py_exec, "-m", "pip", "install", "--upgrade", "pip", "--quiet"])
    
    # 3. Instalar requerimientos
    req_file = VENV_DIR.parent / "server" / "requirements.txt"
    if req_file.exists():
        console.print(f"\n[yellow]Instalando dependencias desde {req_file}...[/yellow]")
        subprocess.run([py_exec, "-m", "pip", "install", "-r", str(req_file)])
    else:
        console.print("[red]❌ Error: No se encontró server/requirements.txt[/red]")
        
    # 4. Instalar PlatformIO
    console.print("\n[yellow]Instalando PlatformIO Core...[/yellow]")
    subprocess.run([py_exec, "-m", "pip", "install", "platformio"])

    console.print("\n[bold green]✨ ¡Todas las dependencias y entornos están instalados y listos![/bold green]")
