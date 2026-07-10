import rich_click as click
import subprocess
import sys
import os
import signal
import socket
import time
from pathlib import Path
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()
from hub.core.config import ROOT_DIR, VENV_DIR, LOG_DIR

SERVER_DIR = ROOT_DIR / "server"
BRIDGE_PID_FILE = ROOT_DIR / ".bridge.pid"
BRIDGE_LOG_FILE = LOG_DIR / "bridge.log"
BRIDGE_SERVICE_NAME = "iot-bridge.service"
WIN_TASK_NAME = "IoT_Bridge_Relay"

# Opciones por defecto para el Servidor Puente
SERVER_PORT = int(os.environ.get("SERVER_PORT", 8000))
HUB_URL = os.environ.get("HUB_URL", "http://127.0.0.1:5000")

def _systemctl(cmd: str):
    subprocess.run(["sudo", "systemctl", cmd, BRIDGE_SERVICE_NAME])

def get_lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def is_port_open(port: int) -> bool:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        res = s.connect_ex(("127.0.0.1", port))
        s.close()
        return res == 0
    except Exception:
        return False

def is_process_running(pid: int) -> bool:
    if sys.platform == "win32":
        try:
            res = subprocess.run(["tasklist", "/FI", f"PID eq {pid}"], capture_output=True, text=True)
            return str(pid) in res.stdout
        except Exception:
            return False
    else:
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

def _show_bridge_status():
    running = False
    pid_val = None

    if BRIDGE_PID_FILE.exists():
        try:
            pid_val = int(BRIDGE_PID_FILE.read_text().strip())
            if is_process_running(pid_val):
                running = True
            else:
                BRIDGE_PID_FILE.unlink(missing_ok=True)
                pid_val = None
        except Exception:
            pass

    if not running and is_port_open(SERVER_PORT):
        running = True

    lan_ip = get_lan_ip()
    status_str = "[bold green]🟢 ACTIVO (Corriendo / Escuchando)[/bold green]" if running else "[bold red]🔴 DETENIDO / INACTIVO[/bold red]"

    table = Table(title="🌐 Estado del Servidor Nube / Relay (Arquitectura Multi-Hub)", show_header=True, header_style="bold magenta")
    table.add_column("Parámetro", style="dim", width=28)
    table.add_column("Valor / Dirección", style="bold")

    table.add_row("Estado del Servicio", status_str)
    table.add_row("🌐 URL Local (Loopback)", f"http://127.0.0.1:{SERVER_PORT}")
    table.add_row("🌐 URL Pública / LAN", f"http://{lan_ip}:{SERVER_PORT}")
    table.add_row("🔗 Modo Multi-Hub", "Activado (Maneja múltiples Hubs)")
    if pid_val:
        table.add_row("⚙️ PID de Proceso", str(pid_val))

    console.print()
    console.print(table)
    console.print()
    if not running:
        console.print("[yellow]💡 Consejo: Puedes arrancar el puente seleccionando '▶️ Iniciar Servidor Puente' o ejecutando 'python iot.py bridge start'.[/yellow]\n")

@click.group()
def bridge():
    """Gestión y Servicios del Servidor Puente / Relay (Teléfono <-> Hub)"""
    pass

@bridge.command()
def start():
    """Arranca el servidor puente en primer plano (Foreground)"""
    console.print(Panel("[bold magenta]Iniciando Servidor Puente / Relay (Primer Plano)[/bold magenta]"))
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable
    try:
        subprocess.run([py_exec, str(SERVER_DIR / "main.py")])
    except KeyboardInterrupt:
        console.print("[yellow]Servidor Puente detenido por el usuario.[/yellow]")

@bridge.command(name="service-status")
def service_status():
    """Muestra IP, puerto, estado y detalles del servidor puente"""
    _show_bridge_status()

@bridge.command(name="service-start")
def service_start():
    """Inicia el servidor puente en segundo plano (Background)"""
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}").exists():
        console.print("[yellow]Iniciando servicio systemd del Puente en Linux...[/yellow]")
        _systemctl("start")
        _show_bridge_status()
        return

    if BRIDGE_PID_FILE.exists():
        try:
            pid = int(BRIDGE_PID_FILE.read_text().strip())
            if is_process_running(pid):
                console.print(f"[yellow]El Servidor Puente ya está ejecutándose en segundo plano (PID: {pid}).[/yellow]")
                _show_bridge_status()
                return
        except Exception:
            pass

    console.print("[green]Arrancando Servidor Puente en segundo plano...[/green]")
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable

    LOG_DIR.mkdir(exist_ok=True)
    env_vars = os.environ.copy()
    env_vars["BRIDGE_BACKGROUND"] = "1"

    try:
        if sys.platform == "win32":
            flags = 0x00000008 | 0x00000200
            with open(BRIDGE_LOG_FILE, "a", encoding="utf-8") as f:
                proc = subprocess.Popen(
                    [py_exec, str(SERVER_DIR / "main.py")],
                    stdout=f,
                    stderr=f,
                    creationflags=flags,
                    cwd=str(ROOT_DIR),
                    env=env_vars
                )
        else:
            with open(BRIDGE_LOG_FILE, "a", encoding="utf-8") as f:
                proc = subprocess.Popen(
                    [py_exec, str(SERVER_DIR / "main.py")],
                    stdout=f,
                    stderr=f,
                    start_new_session=True,
                    cwd=str(ROOT_DIR),
                    env=env_vars
                )

        time.sleep(1.5)
        if proc.poll() is None:
            BRIDGE_PID_FILE.write_text(str(proc.pid))
            console.print(f"[bold green]✔ Servidor Puente iniciado correctamente (PID: {proc.pid}).[/bold green]")
        else:
            console.print(f"[bold red]❌ El Servidor Puente se cerró inesperadamente (código: {proc.returncode}). Revisa {BRIDGE_LOG_FILE}[/bold red]")
            return

        time.sleep(1)
        if is_port_open(SERVER_PORT):
            console.print(f"[bold cyan]🚀 ¡Servidor Puente respondiendo en http://127.0.0.1:{SERVER_PORT}![/bold cyan]")
        else:
            console.print("[yellow]⏳ El proceso sigue ejecutándose; el puerto tardará un momento en responder.[/yellow]")
            
        _show_bridge_status()
    except Exception as e:
        console.print(f"[red]❌ Error al arrancar Servidor Puente: {e}[/red]")

@bridge.command(name="service-stop")
def service_stop():
    """Detiene el servidor puente en segundo plano"""
    stopped = False
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}").exists():
        console.print("[yellow]Deteniendo servicio systemd del puente...[/yellow]")
        _systemctl("stop")
        stopped = True

    if BRIDGE_PID_FILE.exists():
        try:
            pid = int(BRIDGE_PID_FILE.read_text().strip())
            if is_process_running(pid):
                console.print(f"[yellow]Terminando proceso del Servidor Puente (PID: {pid})...[/yellow]")
                if sys.platform == "win32":
                    subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
                else:
                    os.kill(pid, signal.SIGTERM)
                stopped = True
        except Exception:
            pass
        BRIDGE_PID_FILE.unlink(missing_ok=True)

    if stopped:
        console.print("[bold green]✔ Servidor Puente detenido correctamente.[/bold green]")
    else:
        console.print("[dim]No se encontró ningún proceso del puente activo en segundo plano.[/dim]")
    _show_bridge_status()

@bridge.command(name="service-restart")
def service_restart():
    """Reinicia el servidor puente en segundo plano"""
    service_stop.callback()
    service_start.callback()

@bridge.command(name="service-uninstall")
def service_uninstall():
    """Elimina y desinstala el servicio del Servidor Puente"""
    console.print("[yellow]🗑️ Eliminando y limpiando Servidor Puente...[/yellow]")
    service_stop.callback()

    if sys.platform == "win32":
        try:
            subprocess.run(["schtasks", "/Delete", "/TN", WIN_TASK_NAME, "/F"], capture_output=True)
            console.print(f"[green]✔ Tarea programada '{WIN_TASK_NAME}' de Windows eliminada.[/green]")
        except Exception:
            pass
    elif Path(f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}").exists():
        try:
            subprocess.run(["sudo", "systemctl", "disable", BRIDGE_SERVICE_NAME], capture_output=True)
            subprocess.run(["sudo", "rm", "-f", f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}"], check=True)
            subprocess.run(["sudo", "systemctl", "daemon-reload"])
            console.print("[green]✔ Servicio systemd eliminado de /etc/systemd/system/.[/green]")
        except Exception as e:
            console.print(f"[red]Error eliminando archivo systemd: {e}[/red]")

    BRIDGE_PID_FILE.unlink(missing_ok=True)
    console.print("[bold green]✔ ¡Servidor Puente eliminado y entorno limpio![/bold green]\n")

@bridge.command(name="service-install")
def service_install():
    """Instala el servidor puente como servicio (Linux Systemd / Windows Task)"""
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable

    main_path = str(SERVER_DIR / "main.py")

    if sys.platform == "win32":
        console.print(f"[yellow]Instalando Tarea Automática en Windows ('{WIN_TASK_NAME}')...[/yellow]")
        cmd = [
            "schtasks", "/Create", "/TN", WIN_TASK_NAME,
            "/TR", f'"{py_exec}" "{main_path}"',
            "/SC", "ONLOGON", "/F"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            console.print(f"[bold green]✔ Tarea de inicio automático '{WIN_TASK_NAME}' creada con éxito en Windows.[/bold green]")
            console.print("[dim]El Servidor Puente se iniciará automáticamente cada vez que inicies sesión en Windows.[/dim]")
        else:
            console.print(f"[red]❌ No se pudo crear la tarea (puede requerir permisos de Administrador): {res.stderr}[/red]")
        return

    SERVICE_PATH = Path(f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}")
    log_path = str(BRIDGE_LOG_FILE)

    svc = f"""[Unit]
Description=IoT Bridge Relay — Servidor Puente Colmena
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory={ROOT_DIR}
ExecStart={py_exec} {main_path}
Restart=always
RestartSec=3
StandardOutput=append:{log_path}
StandardError=append:{log_path}
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
"""
    try:
        with open("/tmp/iot-bridge.service", "w") as f:
            f.write(svc)
        subprocess.run(["sudo", "mv", "/tmp/iot-bridge.service", str(SERVICE_PATH)], check=True)
        subprocess.run(["sudo", "systemctl", "daemon-reload"])
        subprocess.run(["sudo", "systemctl", "enable", BRIDGE_SERVICE_NAME])
        console.print(f"[green]✔ Servicio instalado en {SERVICE_PATH}[/green]")
    except Exception as e:
        console.print(f"[red]❌ Error al instalar servicio: {e}[/red]")

@bridge.command(name="service-logs")
def service_logs():
    """Muestra los logs en vivo del servidor puente"""
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{BRIDGE_SERVICE_NAME}").exists():
        console.print(f"[yellow]Mostrando journalctl para {BRIDGE_SERVICE_NAME} (Ctrl+C para salir)...[/yellow]")
        subprocess.run(["sudo", "journalctl", "-u", BRIDGE_SERVICE_NAME, "-f", "-n", "50"])
    elif BRIDGE_LOG_FILE.exists():
        console.print(f"[yellow]📜 Mostrando últimas 40 líneas de registro ({BRIDGE_LOG_FILE}):[/yellow]\n")
        try:
            lines = BRIDGE_LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines()
            for line in lines[-40:]:
                console.print(line)
        except Exception as e:
            console.print(f"[red]Error leyendo logs: {e}[/red]")
    else:
        console.print("[dim]No hay archivo de registro bridge.log generado aún. Inicia el servidor para generar logs.[/dim]")
