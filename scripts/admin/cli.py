import click
import subprocess
import sys
import os
from pathlib import Path
from rich.console import Console
from rich.panel import Panel

console = Console()
from core.config import SERVER_DIR, VENV_DIR

SERVICE_NAME = "iot-rf-gateway.service"

def _systemctl(cmd: str):
    subprocess.run(["sudo", "systemctl", cmd, SERVICE_NAME])

@click.group()
def admin():
    """Herramientas de administracion del servidor"""
    pass

@admin.command()
def start():
    """Arranca el servidor en primer plano"""
    console.print(Panel("[bold green]Iniciando Servidor IoT[/bold green]"))
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable
    try:
        subprocess.run([py_exec, str(SERVER_DIR / "main.py")])
    except KeyboardInterrupt:
        console.print("[yellow]Servidor detenido por el usuario.[/yellow]")

@admin.command(name="service-install")
def service_install():
    """Instala el servicio systemd (Solo Linux)"""
    if sys.platform == "win32":
        console.print("[red]Este comando es exclusivo para Linux/Raspberry Pi con systemd.[/red]")
        return
        
    SERVICE_PATH = Path(f"/etc/systemd/system/{SERVICE_NAME}")
    
    # Generate service string
    python_path = str(VENV_DIR / "bin" / "python")
    main_path = str(SERVER_DIR / "main.py")
    log_path = str(SERVER_DIR.parent / "logs" / "server.log")
    
    svc = f"""[Unit]
Description=IoT RF Gateway — Servidor Flask
After=network.target

[Service]
Type=simple
User={os.getenv('USER', 'root')}
WorkingDirectory={SERVER_DIR.parent}
ExecStart={python_path} {main_path}
Restart=on-failure
RestartSec=5
StandardOutput=append:{log_path}
StandardError=append:{log_path}
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
"""
    try:
        with open("/tmp/iot.service", "w") as f:
            f.write(svc)
        subprocess.run(["sudo", "mv", "/tmp/iot.service", str(SERVICE_PATH)], check=True)
        subprocess.run(["sudo", "systemctl", "daemon-reload"])
        subprocess.run(["sudo", "systemctl", "enable", SERVICE_NAME])
        console.print(f"[green]Servicio instalado en {SERVICE_PATH}[/green]")
    except Exception as e:
        console.print(f"[red]Error al instalar servicio: {e}[/red]")


@admin.command(name="service-start")
def service_start():
    if sys.platform == "win32": return
    console.print("[yellow]Iniciando servicio...[/yellow]")
    _systemctl("start")

@admin.command(name="service-stop")
def service_stop():
    if sys.platform == "win32": return
    console.print("[yellow]Deteniendo servicio...[/yellow]")
    _systemctl("stop")

@admin.command(name="service-restart")
def service_restart():
    if sys.platform == "win32": return
    console.print("[yellow]Reiniciando servicio...[/yellow]")
    _systemctl("restart")

@admin.command(name="service-status")
def service_status():
    if sys.platform == "win32": return
    console.print("[yellow]Estado del servicio...[/yellow]")
    subprocess.run(["systemctl", "status", SERVICE_NAME, "--no-pager", "-n", "10"])

@admin.command(name="service-logs")
def service_logs():
    if sys.platform == "win32": return
    console.print(f"[yellow]Mostrando journalctl para {SERVICE_NAME} (Ctrl+C para salir)[/yellow]")
    subprocess.run(["sudo", "journalctl", "-u", SERVICE_NAME, "-f", "-n", "50"])
