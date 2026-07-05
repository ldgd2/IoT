import rich_click as click
import subprocess
import sys
import os
import signal
import socket
from pathlib import Path
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()
from hub.core.config import HUB_DIR, VENV_DIR, LOG_DIR, PID_FILE, API_PORT, RF_PORT, RF_BAUD

SERVICE_NAME = "iot-rf-gateway.service"

def _systemctl(cmd: str):
    subprocess.run(["sudo", "systemctl", cmd, SERVICE_NAME])

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

def _show_status():
    running = False
    pid_val = None

    # 1. Verificamos si hay un PID guardado y si el proceso vive
    if PID_FILE.exists():
        try:
            pid_val = int(PID_FILE.read_text().strip())
            if is_process_running(pid_val):
                running = True
            else:
                # PID obsoleto
                PID_FILE.unlink(missing_ok=True)
                pid_val = None
        except Exception:
            pass

    # 2. Si no encontramos PID pero el puerto HTTP está respondiendo, el servidor está activo
    if not running and is_port_open(API_PORT):
        running = True

    lan_ip = get_lan_ip()
    status_str = "[bold green]🟢 ACTIVO (Corriendo / Escuchando)[/bold green]" if running else "[bold red]🔴 DETENIDO / INACTIVO[/bold red]"

    table = Table(title="📊 Estado del Servidor y Servicio IoT Colmena", show_header=True, header_style="bold cyan")
    table.add_column("Parámetro", style="dim", width=28)
    table.add_column("Valor / Dirección", style="bold")

    table.add_row("Estado del Servicio", status_str)
    table.add_row("🌐 URL Local (Esta PC)", f"http://127.0.0.1:{API_PORT}")
    table.add_row("🌐 URL en Red WiFi / LAN", f"http://{lan_ip}:{API_PORT}")
    table.add_row("🔌 Puerto Radio RF", f"{RF_PORT} (@ {RF_BAUD} bps)")
    if pid_val:
        table.add_row("⚙️ PID de Proceso", str(pid_val))

    console.print()
    console.print(table)
    console.print()
    if not running:
        console.print("[yellow]💡 Consejo: Puedes arrancar el servidor seleccionando '▶️ Iniciar Servicio / Servidor' o '🚀 Arrancar Servidor (Foreground)'.[/yellow]\n")

@click.group()
def admin():
    """Herramientas de administración del servidor y servicios"""
    pass

@admin.command()
def start():
    """Arranca el servidor en primer plano (Foreground)"""
    console.print(Panel("[bold green]Iniciando Servidor IoT (Primer Plano)[/bold green]"))
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable
    try:
        subprocess.run([py_exec, str(HUB_DIR / "main.py")])
    except KeyboardInterrupt:
        console.print("[yellow]Servidor detenido por el usuario.[/yellow]")

@admin.command(name="service-status")
def service_status():
    """Muestra IP, puerto, estado y detalles del servicio actualmente"""
    _show_status()

@admin.command(name="service-start")
def service_start():
    """Inicia el servicio / servidor en segundo plano (Background)"""
    # En Linux, si existe el servicio systemd, usar systemctl
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{SERVICE_NAME}").exists():
        console.print("[yellow]Iniciando servicio systemd en Linux...[/yellow]")
        _systemctl("start")
        _show_status()
        return

    # Si ya está corriendo, avisar
    if PID_FILE.exists():
        try:
            pid = int(PID_FILE.read_text().strip())
            if is_process_running(pid):
                console.print(f"[yellow] El servidor ya está ejecutándose en segundo plano (PID: {pid}).[/yellow]")
                _show_status()
                return
        except Exception:
            pass

    console.print("[green] Arrancando Servidor IoT en segundo plano...[/green]")
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable

    log_path = LOG_DIR / "hub.log"
    env_vars = os.environ.copy()
    env_vars["HUB_BACKGROUND"] = "1"

    try:
        if sys.platform == "win32":
            # DETACHED_PROCESS = 0x00000008, CREATE_NEW_PROCESS_GROUP = 0x00000200
            flags = 0x00000008 | 0x00000200
            proc = subprocess.Popen(
                [py_exec, str(HUB_DIR / "main.py")],
                creationflags=flags,
                env=env_vars,
                cwd=str(HUB_DIR.parent)
            )
        else:
            proc = subprocess.Popen(
                [py_exec, str(HUB_DIR / "main.py")],
                env=env_vars,
                cwd=str(HUB_DIR.parent),
                start_new_session=True
            )
        PID_FILE.write_text(str(proc.pid))
        console.print(f"[bold green]✔ Servidor iniciado en segundo plano (PID: {proc.pid}). Logs en {log_path}[/bold green]")
        
        import time
        console.print("[dim]⏳ Esperando 2.5 segundos para verificar que el servicio arranque y abra el puerto HTTP...[/dim]")
        time.sleep(2.5)
        if is_port_open(API_PORT):
            console.print(f"[bold green]✔ ¡Éxito! Servidor respondiendo en http://127.0.0.1:{API_PORT}[/bold green]")
        else:
            if not is_process_running(proc.pid):
                console.print("[bold red]⚠️ Alerta: El proceso se cerró inmediatamente al iniciar. Revisa si el puerto COM o el puerto HTTP 5000 ya están ocupados o si hay un error en logs/hub.log[/bold red]")
                if log_path.exists():
                    console.print("[yellow]--- Últimas 5 líneas de logs/hub.log ---[/yellow]")
                    lines = log_path.read_text(errors="replace").splitlines()[-5:]
                    for l in lines:
                        console.print(f"  [dim]{l}[/dim]")
            else:
                console.print("[yellow]⏳ El proceso sigue ejecutándose pero el puerto HTTP aún no responde. Puede tardar unos segundos más en cargar.[/yellow]")
                
        _show_status()
    except Exception as e:
        console.print(f"[red]❌ Error al arrancar servidor: {e}[/red]")

@admin.command(name="service-stop")
def service_stop():
    """Detiene el servicio o servidor en segundo plano"""
    stopped = False
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{SERVICE_NAME}").exists():
        console.print("[yellow]Deteniendo servicio systemd...[/yellow]")
        _systemctl("stop")
        stopped = True

    if PID_FILE.exists():
        try:
            pid = int(PID_FILE.read_text().strip())
            if is_process_running(pid):
                console.print(f"[yellow]Terminando proceso en segundo plano (PID: {pid})...[/yellow]")
                if sys.platform == "win32":
                    subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
                else:
                    os.kill(pid, signal.SIGTERM)
                stopped = True
        except Exception:
            pass
        PID_FILE.unlink(missing_ok=True)

    if stopped:
        console.print("[bold green]✔ Servidor detenido correctamente.[/bold green]")
    else:
        console.print("[dim]No se encontró ningún proceso en segundo plano activo.[/dim]")
    _show_status()

@admin.command(name="service-restart")
def service_restart():
    """Reinicia el servicio o servidor en segundo plano"""
    service_stop.callback()
    service_start.callback()

@admin.command(name="service-uninstall")
def service_uninstall():
    """Elimina y desinstala el servicio actualmente configurado"""
    console.print("[yellow]🗑️ Eliminando y limpiando servicio actual...[/yellow]")
    # 1. Detener procesos
    service_stop.callback()

    # 2. Si es Linux y existe systemd, desinstalar
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{SERVICE_NAME}").exists():
        try:
            subprocess.run(["sudo", "systemctl", "disable", SERVICE_NAME], capture_output=True)
            subprocess.run(["sudo", "rm", "-f", f"/etc/systemd/system/{SERVICE_NAME}"], check=True)
            subprocess.run(["sudo", "systemctl", "daemon-reload"])
            console.print("[green]✔ Servicio systemd eliminado de /etc/systemd/system/.[/green]")
        except Exception as e:
            console.print(f"[red]Error eliminando archivo systemd: {e}[/red]")

    # 3. Limpiar PID y temporales
    PID_FILE.unlink(missing_ok=True)
    console.print("[bold green]✔ ¡Servicio eliminado por completo y entorno limpio![/bold green]\n")

@admin.command(name="service-install")
def service_install():
    """Instala el servicio systemd (Solo Linux / Raspberry Pi)"""
    if sys.platform == "win32":
        console.print("[yellow]ℹ️ En Windows no es necesario instalar un servicio de systemd. Puedes arrancar y gestionar el servidor en segundo plano usando '▶️ Iniciar Servicio / Servidor'.[/yellow]")
        return

    SERVICE_PATH = Path(f"/etc/systemd/system/{SERVICE_NAME}")
    python_path = str(VENV_DIR / "bin" / "python")
    main_path = str(HUB_DIR / "main.py")
    log_path = str(HUB_DIR.parent / "logs" / "hub.log")

    subprocess.run(["sudo", "sh", "-c", "chmod 666 /dev/ttyACM* /dev/ttyUSB* /dev/hidraw* 2>/dev/null || true"])

    svc = f"""[Unit]
Description=IoT RF Gateway — Servidor Flask
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory={HUB_DIR.parent}
ExecStart={python_path} {main_path}
Restart=always
RestartSec=3
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
        console.print(f"[green]✔ Servicio instalado en {SERVICE_PATH}[/green]")
    except Exception as e:
        console.print(f"[red]❌ Error al instalar servicio: {e}[/red]")

@admin.command(name="service-logs")
def service_logs():
    """Muestra los logs en vivo del servidor o servicio"""
    log_path = LOG_DIR / "hub.log"
    if sys.platform != "win32" and Path(f"/etc/systemd/system/{SERVICE_NAME}").exists():
        console.print(f"[yellow]Mostrando journalctl para {SERVICE_NAME} (Ctrl+C para salir)...[/yellow]")
        subprocess.run(["sudo", "journalctl", "-u", SERVICE_NAME, "-f", "-n", "50"])
    elif log_path.exists():
        console.print(f"[yellow]📜 Mostrando últimas 40 líneas de registro ({log_path}):[/yellow]\n")
        try:
            lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
            for line in lines[-40:]:
                console.print(line)
        except Exception as e:
            console.print(f"[red]Error leyendo logs: {e}[/red]")
    else:
        console.print("[dim]No hay archivo de registro hub.log generado aún. Inicia el servidor para generar logs.[/dim]")

