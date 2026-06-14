#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
"""
╔══════════════════════════════════════════════════════╗
║          IoT RF Gateway — CLI Manager                ║
║  Servidor ultra-liviano para dispositivos RF         ║
╚══════════════════════════════════════════════════════╝

Uso:
  python run.py              → Menú interactivo
  python run.py start        → Arrancar servidor
  python run.py stop         → Detener servidor
  python run.py logs         → Ver logs en vivo
  python run.py install      → Instalar dependencias
  python run.py venv         → Crear entorno virtual
"""

import os
import sys
import json
import time
import signal
import shutil
import platform
import argparse
import textwrap
import subprocess
import socket
from pathlib import Path
from datetime import datetime

# ──────────────────────────────────────────────────────────
#  RED
# ──────────────────────────────────────────────────────────
def get_local_ip() -> str:
    try:
        # Conecta a un DNS externo temporalmente para obtener la IP de red local
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"

# ──────────────────────────────────────────────────────────
#  PATHS
# ──────────────────────────────────────────────────────────
ROOT_DIR    = Path(__file__).parent.resolve()
SERVER_DIR  = ROOT_DIR / "server"
VENV_DIR    = ROOT_DIR / ".venv"
LOG_DIR     = ROOT_DIR / "logs"
PID_FILE    = ROOT_DIR / ".server.pid"
LOG_FILE    = LOG_DIR  / "server.log"
RF_LOG_FILE = LOG_DIR  / "rf.log"

LOG_DIR.mkdir(exist_ok=True)

IS_WINDOWS  = platform.system() == "Windows"
IS_LINUX    = platform.system() == "Linux"
IS_RPI      = IS_LINUX and Path("/proc/device-tree/model").exists()

# ──────────────────────────────────────────────────────────
#  COLORES ANSI (sin dependencias externas)
# ──────────────────────────────────────────────────────────
class C:
    RESET  = "\033[0m"
    BOLD   = "\033[1m"
    DIM    = "\033[2m"
    # Colores
    CYAN   = "\033[96m"
    BLUE   = "\033[94m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    MAGENTA= "\033[95m"
    WHITE  = "\033[97m"
    GRAY   = "\033[90m"
    # Fondo
    BG_DARK= "\033[48;5;235m"

    @staticmethod
    def disable():
        for attr in vars(C):
            if not attr.startswith("_") and attr != "disable":
                setattr(C, attr, "")


# Deshabilitar colores en Windows sin soporte ANSI
if IS_WINDOWS:
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        C.disable()


# ──────────────────────────────────────────────────────────
#  UTILIDADES DE IMPRESIÓN
# ──────────────────────────────────────────────────────────
def _w(text: str):
    """Print sin newline al final."""
    print(text, end="", flush=True)

def info(msg):   print(f"{C.CYAN}  ℹ  {C.RESET}{msg}")
def ok(msg):     print(f"{C.GREEN}  ✔  {C.RESET}{msg}")
def warn(msg):   print(f"{C.YELLOW}  ⚠  {C.RESET}{msg}")
def err(msg):    print(f"{C.RED}  ✖  {C.RESET}{msg}")
def step(msg):   print(f"{C.MAGENTA}  →  {C.RESET}{C.BOLD}{msg}{C.RESET}")
def dim(msg):    print(f"     {C.GRAY}{msg}{C.RESET}")


def banner():
    print()
    print(f"{C.CYAN}{C.BOLD}", end="")
    print(r"  ██████╗ ███████╗     ██████╗  █████╗ ████████╗███████╗")
    print(r"  ██╔══██╗██╔════╝    ██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝")
    print(r"  ██████╔╝█████╗      ██║  ███╗███████║   ██║   █████╗  ")
    print(r"  ██╔══██╗██╔══╝      ██║   ██║██╔══██║   ██║   ██╔══╝  ")
    print(r"  ██║  ██║██║         ╚██████╔╝██║  ██║   ██║   ███████╗")
    print(r"  ╚═╝  ╚═╝╚═╝          ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝")
    print(C.RESET, end="")
    print(f"  {C.GRAY}IoT RF Gateway — Manager CLI{C.RESET}")
    print(f"  {C.GRAY}Platform: {platform.system()} {platform.machine()}", end="")
    if IS_RPI:
        print(f" {C.GREEN}[Raspberry Pi detectado]", end="")
    print(C.RESET)
    print()


def separator(title: str = ""):
    width = 56
    if title:
        pad = (width - len(title) - 2) // 2
        print(f"  {C.GRAY}{'─' * pad} {C.CYAN}{title}{C.GRAY} {'─' * pad}{C.RESET}")
    else:
        print(f"  {C.GRAY}{'─' * width}{C.RESET}")


def confirm(prompt: str) -> bool:
    ans = input(f"  {C.YELLOW}?  {C.RESET}{prompt} {C.DIM}[s/N]{C.RESET} ").strip().lower()
    return ans in ("s", "si", "sí", "y", "yes")


def pause():
    input(f"\n  {C.GRAY}Presiona Enter para continuar...{C.RESET}")


# ──────────────────────────────────────────────────────────
#  ESTADO DEL SERVIDOR
# ──────────────────────────────────────────────────────────
def get_pid() -> int | None:
    if PID_FILE.exists():
        try:
            return int(PID_FILE.read_text().strip())
        except Exception:
            pass
    return None


def is_running(pid: int | None = None) -> bool:
    pid = pid or get_pid()
    if not pid:
        return False
    try:
        if IS_WINDOWS:
            result = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}"],
                capture_output=True, text=True
            )
            return str(pid) in result.stdout
        else:
            os.kill(pid, 0)
            return True
    except (ProcessLookupError, PermissionError):
        return False


def server_status_str() -> str:
    pid = get_pid()
    if pid and is_running(pid):
        return f"{C.GREEN}● En línea{C.RESET} {C.GRAY}(PID {pid}){C.RESET}"
    return f"{C.RED}○ Detenido{C.RESET}"


# ──────────────────────────────────────────────────────────
#  PYTHON / VENV HELPERS
# ──────────────────────────────────────────────────────────
def python_bin() -> str:
    """Devuelve el ejecutable Python a usar (venv si existe)."""
    if IS_WINDOWS:
        venv_py = VENV_DIR / "Scripts" / "python.exe"
    else:
        venv_py = VENV_DIR / "bin" / "python"
    if venv_py.exists():
        return str(venv_py)
    return sys.executable


def pip_bin() -> str:
    if IS_WINDOWS:
        venv_pip = VENV_DIR / "Scripts" / "pip.exe"
    else:
        venv_pip = VENV_DIR / "bin" / "pip"
    if venv_pip.exists():
        return str(venv_pip)
    return f"{sys.executable} -m pip"


def run_cmd(cmd: list, cwd=None, check=True, capture=False) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, cwd=cwd or ROOT_DIR,
        check=check,
        capture_output=capture,
        text=True
    )


# ──────────────────────────────────────────────────────────
#  ACCIONES
# ──────────────────────────────────────────────────────────

# ── 1. INSTALAR DEPENDENCIAS ──────────────────────────────
def cmd_install():
    separator("Instalar Dependencias")
    req_file = SERVER_DIR / "requirements.txt"
    if not req_file.exists():
        err(f"No se encontró {req_file}")
        return

    step("Instalando dependencias del servidor...")
    pip = [python_bin(), "-m", "pip", "install", "-r", str(req_file), "--upgrade"]
    try:
        subprocess.run(pip, check=True)
        ok("Dependencias instaladas correctamente.")
    except subprocess.CalledProcessError:
        err("Falló la instalación. Verifica el entorno Python.")
    pause()


# ── 2. CREAR ENTORNO VIRTUAL ──────────────────────────────
def cmd_venv():
    separator("Entorno Virtual")
    if VENV_DIR.exists():
        warn(f"Ya existe un entorno virtual en {VENV_DIR}")
        if not confirm("¿Recrear el entorno virtual?"):
            return
        step("Eliminando entorno anterior...")
        shutil.rmtree(VENV_DIR)

    step(f"Creando entorno virtual en {VENV_DIR} ...")
    try:
        run_cmd([sys.executable, "-m", "venv", str(VENV_DIR)])
        ok("Entorno virtual creado.")
        info(f"Python: {python_bin()}")
        info("Ahora puedes instalar dependencias con la opción [2].")
    except subprocess.CalledProcessError:
        err("No se pudo crear el entorno virtual.")
    pause()


# ── 3. ARRANCAR SERVIDOR ──────────────────────────────────
def cmd_start(foreground=False):
    separator("Arrancar Servidor")
    if is_running():
        warn(f"El servidor ya está corriendo. {server_status_str()}")
        pause()
        return

    app_file = SERVER_DIR / "app.py"
    if not app_file.exists():
        err(f"No se encontró {app_file}")
        pause()
        return

    py = python_bin()
    cmd = [py, str(app_file)]

    if foreground:
        step("Iniciando servidor en primer plano (Ctrl+C para detener)...")
        print()
        try:
            proc = subprocess.run(cmd, cwd=str(SERVER_DIR))
        except KeyboardInterrupt:
            print()
            ok("Servidor detenido.")
        return

    # Background
    step("Iniciando servidor en segundo plano...")
    LOG_FILE.parent.mkdir(exist_ok=True)
    log_fh = open(LOG_FILE, "a")
    log_fh.write(f"\n\n{'='*60}\n[{datetime.now()}] INICIO\n{'='*60}\n")

    if IS_WINDOWS:
        proc = subprocess.Popen(
            cmd, cwd=str(SERVER_DIR),
            stdout=log_fh, stderr=log_fh,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
        )
    else:
        proc = subprocess.Popen(
            cmd, cwd=str(SERVER_DIR),
            stdout=log_fh, stderr=log_fh,
            start_new_session=True
        )

    PID_FILE.write_text(str(proc.pid))
    time.sleep(1.5)

    if is_running(proc.pid):
        ok(f"Servidor iniciado — PID {proc.pid}")
        info(f"Dashboard → http://{get_local_ip()}:5000")
        info(f"Logs en   → {LOG_FILE}")
    else:
        err("El proceso terminó inesperadamente. Revisa los logs.")
    pause()


# ── 4. DETENER SERVIDOR ───────────────────────────────────
def cmd_stop():
    separator("Detener Servidor")
    pid = get_pid()
    if not pid or not is_running(pid):
        warn("El servidor no está corriendo.")
        PID_FILE.unlink(missing_ok=True)
        pause()
        return

    step(f"Deteniendo servidor (PID {pid})...")
    try:
        if IS_WINDOWS:
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=True, capture_output=True)
        else:
            os.kill(pid, signal.SIGTERM)
            time.sleep(1)
            if is_running(pid):
                os.kill(pid, signal.SIGKILL)
    except Exception as e:
        err(f"No se pudo detener: {e}")
        pause()
        return

    PID_FILE.unlink(missing_ok=True)
    ok("Servidor detenido correctamente.")
    pause()


# ── 5. REINICIAR SERVIDOR ─────────────────────────────────
def cmd_restart():
    separator("Reiniciar Servidor")
    step("Reiniciando...")
    cmd_stop_silent()
    time.sleep(0.5)
    cmd_start()


def cmd_stop_silent():
    pid = get_pid()
    if not pid or not is_running(pid):
        PID_FILE.unlink(missing_ok=True)
        return
    try:
        if IS_WINDOWS:
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
        else:
            os.kill(pid, signal.SIGTERM)
            time.sleep(0.8)
    except Exception:
        pass
    PID_FILE.unlink(missing_ok=True)


# ── 6. VER LOGS EN VIVO ───────────────────────────────────
def cmd_logs():
    separator("Logs del Servidor")
    if not LOG_FILE.exists():
        warn(f"Aún no hay logs en {LOG_FILE}")
        pause()
        return

    step(f"Mostrando {LOG_FILE}  (Ctrl+C para salir)")
    print(f"  {C.GRAY}{'─'*52}{C.RESET}\n")

    try:
        if IS_WINDOWS:
            subprocess.run(["powershell", "-Command",
                f"Get-Content -Path '{LOG_FILE}' -Wait -Tail 40"])
        else:
            subprocess.run(["tail", "-n", "40", "-f", str(LOG_FILE)])
    except KeyboardInterrupt:
        print()
        ok("Saliendo del log.")
    pause()


# ── 7. ESTADO DEL SISTEMA ────────────────────────────────
def cmd_status():
    separator("Estado del Sistema")
    print()

    # Servidor
    print(f"  {C.BOLD}Servidor Flask{C.RESET}")
    print(f"    Estado  :  {server_status_str()}")
    pid = get_pid()
    if pid and is_running(pid):
        print(f"    URL     :  {C.CYAN}http://{get_local_ip()}:5000{C.RESET}")
        print(f"    Log     :  {C.GRAY}{LOG_FILE}{C.RESET}")

    print()

    # Entorno Python
    print(f"  {C.BOLD}Entorno Python{C.RESET}")
    print(f"    Python  :  {C.GRAY}{python_bin()}{C.RESET}")
    venv_ok = (VENV_DIR / ("Scripts" if IS_WINDOWS else "bin")).exists()
    print(f"    venv    :  {'✔ existe' if venv_ok else '✖ no creado'}")

    req_file = SERVER_DIR / "requirements.txt"
    # Verificar flask instalado
    try:
        result = subprocess.run(
            [python_bin(), "-c", "import flask; print(flask.__version__)"],
            capture_output=True, text=True
        )
        flask_v = result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        flask_v = None
    print(f"    Flask   :  {C.GREEN + flask_v if flask_v else C.RED + 'no instalado'}{C.RESET}")

    print()

    # Plataforma
    print(f"  {C.BOLD}Hardware / OS{C.RESET}")
    print(f"    OS      :  {C.GRAY}{platform.system()} {platform.release()}{C.RESET}")
    print(f"    Arch    :  {C.GRAY}{platform.machine()}{C.RESET}")
    if IS_RPI:
        try:
            model = Path("/proc/device-tree/model").read_text().strip("\x00")
            print(f"    Modelo  :  {C.GREEN}{model}{C.RESET}")
        except Exception:
            pass

    print()

    # Directorios
    print(f"  {C.BOLD}Rutas{C.RESET}")
    print(f"    Proyecto:  {C.GRAY}{ROOT_DIR}{C.RESET}")
    print(f"    Servidor:  {C.GRAY}{SERVER_DIR}{C.RESET}")
    print(f"    Logs    :  {C.GRAY}{LOG_DIR}{C.RESET}")

    print()
    pause()


# ── 8. GESTIÓN SERVICIO systemd (Linux) ──────────────────
SERVICE_NAME = "iot-rf-gateway"


def _service_installed() -> bool:
    """True si el .service existe en /etc/systemd/system."""
    return Path(f"/etc/systemd/system/{SERVICE_NAME}.service").exists()


def _systemctl(action: str, capture: bool = False):
    """Ejecuta sudo systemctl <action> <SERVICE_NAME>."""
    return subprocess.run(
        ["sudo", "systemctl", action, SERVICE_NAME],
        capture_output=capture, text=True
    )


def _service_active() -> bool:
    r = subprocess.run(
        ["systemctl", "is-active", SERVICE_NAME],
        capture_output=True, text=True
    )
    return r.stdout.strip() == "active"


def _service_enabled() -> bool:
    r = subprocess.run(
        ["systemctl", "is-enabled", SERVICE_NAME],
        capture_output=True, text=True
    )
    return r.stdout.strip() == "enabled"


def cmd_service_install():
    """Instala el archivo .service en systemd y lo habilita."""
    separator("Instalar Servicio systemd")

    if IS_WINDOWS:
        warn("Esta función solo está disponible en Linux.")
        pause()
        return

    service_file = Path(f"/etc/systemd/system/{SERVICE_NAME}.service")
    py_exec  = python_bin()
    app_exec = str(SERVER_DIR / "app.py")
    user     = os.getenv("USER", "pi")

    unit = textwrap.dedent(f"""\
        [Unit]
        Description=IoT RF Gateway — Servidor Flask
        After=network.target

        [Service]
        Type=simple
        User={user}
        WorkingDirectory={SERVER_DIR}
        ExecStart={py_exec} {app_exec}
        Restart=on-failure
        RestartSec=5
        StandardOutput=append:{LOG_FILE}
        StandardError=append:{LOG_FILE}
        Environment=PYTHONUNBUFFERED=1

        [Install]
        WantedBy=multi-user.target
    """)

    print()
    print(f"{C.GRAY}{unit}{C.RESET}")

    if not confirm(f"¿Instalar el servicio '{SERVICE_NAME}' en /etc/systemd/system/?"):
        return

    step("Escribiendo archivo de servicio (requiere sudo)...")
    try:
        subprocess.run(
            ["sudo", "tee", str(service_file)],
            input=unit, text=True, check=True, capture_output=True
        )
        subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
        subprocess.run(["sudo", "systemctl", "enable", SERVICE_NAME], check=True)
        ok(f"Servicio '{SERVICE_NAME}' instalado y habilitado.")
        info("Usa la opcion [5] del menu para gestionarlo.")
    except subprocess.CalledProcessError as e:
        err(f"No se pudo instalar el servicio: {e}")
    pause()


# Alias para compatibilidad con el menu anterior
def cmd_service_linux():
    cmd_service_manage()


def _print_service_status():
    """Imprime el estado compacto del servicio systemd."""
    installed = _service_installed()
    print()
    print(f"  {C.BOLD}Servicio: {C.CYAN}{SERVICE_NAME}{C.RESET}")
    if not installed:
        print(f"  Instalado : {C.RED}No instalado{C.RESET}")
        return
    active  = _service_active()
    enabled = _service_enabled()
    active_str  = f"{C.GREEN}activo{C.RESET}"   if active  else f"{C.RED}inactivo{C.RESET}"
    enabled_str = f"{C.GREEN}habilitado{C.RESET}" if enabled else f"{C.YELLOW}deshabilitado{C.RESET}"
    print(f"  Instalado : {C.GREEN}Si{C.RESET}")
    print(f"  Estado    : {active_str}")
    print(f"  Inicio    : {enabled_str}")
    print()

    # systemctl status (compacto)
    r = subprocess.run(
        ["systemctl", "status", SERVICE_NAME, "--no-pager", "-l", "-n", "5"],
        capture_output=True, text=True
    )
    for line in r.stdout.splitlines():
        print(f"  {C.GRAY}{line}{C.RESET}")


def cmd_service_manage():
    """Submenú completo de gestión del servicio systemd."""
    if IS_WINDOWS:
        warn("Esta función solo está disponible en Linux.")
        pause()
        return

    while True:
        os.system("clear")
        banner()
        installed = _service_installed()
        _print_service_status()

        print()
        separator("Gestion del Servicio systemd")
        print()

        if not installed:
            print(f"  {C.CYAN}  [a]{C.RESET} Instalar servicio")
        else:
            active = _service_active()
            if active:
                print(f"  {C.CYAN}  [p]{C.RESET} Detener servicio")
                print(f"  {C.CYAN}  [r]{C.RESET} Reiniciar servicio")
            else:
                print(f"  {C.CYAN}  [s]{C.RESET} Iniciar servicio")

            print(f"  {C.CYAN}  [e]{C.RESET} Habilitar al inicio (enable)")
            print(f"  {C.CYAN}  [d]{C.RESET} Deshabilitar al inicio (disable)")
            print()
            print(f"  {C.CYAN}  [l]{C.RESET} Ver logs del servidor en vivo (server.log)")
            print(f"  {C.CYAN}  [j]{C.RESET} Ver eventos del sistema     (journalctl -f)")
            print(f"  {C.CYAN}  [J]{C.RESET} Ver eventos del sistema     (ultimos 100)")
            print()
            print(f"  {C.CYAN}  [u]{C.RESET} Desinstalar servicio")

        print()
        print(f"  {C.GRAY}  [q]{C.RESET} Volver al menu principal")
        print()
        separator()
        print()

        choice = input(f"  {C.BOLD}Opcion:{C.RESET} ").strip()

        # ── acciones ──
        if choice == "q":
            break

        elif choice == "a":
            cmd_service_install()

        elif choice == "s":
            step(f"Iniciando {SERVICE_NAME}...")
            r = _systemctl("start", capture=True)
            if r.returncode == 0:
                ok("Servicio iniciado.")
            else:
                err(r.stderr.strip() or "Error al iniciar.")
            pause()

        elif choice == "p":
            step(f"Deteniendo {SERVICE_NAME}...")
            r = _systemctl("stop", capture=True)
            if r.returncode == 0:
                ok("Servicio detenido.")
            else:
                err(r.stderr.strip() or "Error al detener.")
            pause()

        elif choice == "r":
            step(f"Reiniciando {SERVICE_NAME}...")
            r = _systemctl("restart", capture=True)
            if r.returncode == 0:
                ok("Servicio reiniciado.")
            else:
                err(r.stderr.strip() or "Error al reiniciar.")
            pause()

        elif choice == "e":
            step(f"Habilitando {SERVICE_NAME} al inicio...")
            r = _systemctl("enable", capture=True)
            ok("Habilitado.") if r.returncode == 0 else err(r.stderr.strip())
            pause()

        elif choice == "d":
            step(f"Deshabilitando {SERVICE_NAME} del inicio...")
            r = _systemctl("disable", capture=True)
            ok("Deshabilitado.") if r.returncode == 0 else err(r.stderr.strip())
            pause()

        elif choice == "j":
            step(f"journalctl -u {SERVICE_NAME} -f  (Ctrl+C para salir)")
            print(f"  {C.GRAY}{'─'*52}{C.RESET}\n")
            try:
                subprocess.run(
                    ["sudo", "journalctl", "-u", SERVICE_NAME,
                     "-f", "--no-pager", "-n", "40"]
                )
            except KeyboardInterrupt:
                print()
                ok("Saliendo del log.")
            pause()

        elif choice == "J":
            step(f"Ultimas 100 lineas — journalctl -u {SERVICE_NAME}")
            print(f"  {C.GRAY}{'─'*52}{C.RESET}\n")
            subprocess.run(
                ["sudo", "journalctl", "-u", SERVICE_NAME,
                 "--no-pager", "-n", "100"]
            )
            pause()

        elif choice == "l":
            step(f"Log de archivo: {LOG_FILE}  (Ctrl+C para salir)")
            print(f"  {C.GRAY}{'─'*52}{C.RESET}\n")
            if not LOG_FILE.exists():
                warn(f"No existe aun: {LOG_FILE}")
            else:
                try:
                    subprocess.run(["tail", "-n", "60", "-f", str(LOG_FILE)])
                except KeyboardInterrupt:
                    print()
                    ok("Saliendo del log.")
            pause()

        elif choice == "u":
            if not confirm(f"¿Desinstalar el servicio '{SERVICE_NAME}'?"):
                continue
            step("Desinstalando...")
            try:
                _systemctl("stop")
                _systemctl("disable")
                svc_path = Path(f"/etc/systemd/system/{SERVICE_NAME}.service")
                subprocess.run(["sudo", "rm", "-f", str(svc_path)], check=True)
                subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
                ok("Servicio desinstalado correctamente.")
            except subprocess.CalledProcessError as e:
                err(f"Error al desinstalar: {e}")
            pause()

        else:
            warn(f"Opcion invalida: '{choice}'")
            time.sleep(0.5)


# ── 9. CREAR TAREA PROGRAMADA (Windows) ──────────────────
def cmd_service_windows():
    separator("Crear Tarea Programada (Windows)")

    if not IS_WINDOWS:
        warn("Esta función solo está disponible en Windows.")
        pause()
        return

    task_name = "IoT_RF_Gateway"
    py_exec   = python_bin()
    app_exec  = str(SERVER_DIR / "app.py")

    cmd_xml = textwrap.dedent(f"""\
        <?xml version="1.0" encoding="UTF-16"?>
        <Task version="1.2"
          xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
          <Triggers>
            <BootTrigger><Enabled>true</Enabled></BootTrigger>
          </Triggers>
          <Actions Context="Author">
            <Exec>
              <Command>{py_exec}</Command>
              <Arguments>{app_exec}</Arguments>
              <WorkingDirectory>{SERVER_DIR}</WorkingDirectory>
            </Exec>
          </Actions>
          <Settings>
            <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
            <RestartOnFailure>
              <Count>3</Count>
              <Interval>PT1M</Interval>
            </RestartOnFailure>
          </Settings>
        </Task>
    """)

    xml_path = ROOT_DIR / "iot_task.xml"
    xml_path.write_text(cmd_xml, encoding="utf-16")
    step(f"Archivo XML generado: {xml_path}")

    if confirm(f"¿Registrar la tarea '{task_name}' en el Programador de tareas?"):
        try:
            run_cmd(["schtasks", "/Create", "/TN", task_name,
                     "/XML", str(xml_path), "/F"])
            ok(f"Tarea '{task_name}' registrada.")
            info("Comandos útiles:")
            dim(f"  schtasks /Run   /TN {task_name}")
            dim(f"  schtasks /End   /TN {task_name}")
            dim(f"  schtasks /Delete /TN {task_name}")
        except subprocess.CalledProcessError as e:
            err(f"No se pudo crear la tarea: {e}")
            warn("Intenta ejecutar como Administrador.")
    pause()


# ── 10. SIMULAR TRAMA RF ──────────────────────────────────
def cmd_simulate_rf():
    import urllib.request
    import urllib.error

    separator("Simular Trama RF")
    if not is_running():
        warn("El servidor no está corriendo. Inícialo primero.")
        pause()
        return

    print()
    print(f"  {C.BOLD}Selecciona tipo de trama a simular:{C.RESET}")
    print(f"  {C.CYAN}1{C.RESET}. Luz encendida")
    print(f"  {C.CYAN}2{C.RESET}. Luz apagada")
    print(f"  {C.CYAN}3{C.RESET}. Sensor temperatura")
    print(f"  {C.CYAN}4{C.RESET}. Relay activado")
    print(f"  {C.CYAN}5{C.RESET}. Nuevo dispositivo genérico")
    print()
    choice = input("  Opción: ").strip()

    payloads = {
        "1": {"id": "dev_001", "rssi": -62, "payload": {"on": True,  "brightness": 90}},
        "2": {"id": "dev_001", "rssi": -68, "payload": {"on": False, "brightness": 0}},
        "3": {"id": "dev_003", "rssi": -55, "payload": {"temp": round(20 + __import__('random').random()*10, 1), "humidity": round(40 + __import__('random').random()*30, 1)}},
        "4": {"id": "dev_004", "rssi": -71, "payload": {"on": True}},
        "5": {"id": f"dev_new_{int(time.time())%1000:03d}", "name": "Nodo Nuevo", "type": "generic", "rssi": -80, "payload": {"hello": True}},
    }

    data = payloads.get(choice)
    if not data:
        warn("Opción inválida.")
        pause()
        return

    body = json.dumps(data).encode()
    req  = urllib.request.Request(
        f"http://{get_local_ip()}:5000/api/ingest",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            result = json.loads(resp.read())
        ok(f"Trama enviada → {data['id']}")
        dim(f"Payload: {json.dumps(data['payload'])}")
        dim(f"Respuesta: {result}")
    except urllib.error.URLError as e:
        err(f"No se pudo conectar al servidor: {e}")
    pause()


# ── 11. VER DISPOSITIVOS (API) ────────────────────────────
def cmd_devices():
    import urllib.request
    import urllib.error

    separator("Dispositivos Registrados")

    if not is_running():
        warn("El servidor no está corriendo.")
        pause()
        return

    try:
        with urllib.request.urlopen(f"http://{get_local_ip()}:5000/api/devices", timeout=3) as r:
            devices = json.loads(r.read())
    except Exception as e:
        err(f"No se pudo obtener dispositivos: {e}")
        pause()
        return

    if not devices:
        warn("No hay dispositivos registrados.")
        pause()
        return

    # Cabecera tabla
    print()
    print(f"  {C.BOLD}{'ID':<12} {'Nombre':<18} {'Tipo':<9} {'Estado':<10} {'RSSI':<8} {'Msgs'}{C.RESET}")
    print(f"  {C.GRAY}{'─'*62}{C.RESET}")

    for d in devices:
        status_c = C.GREEN if d['status'] == 'online' else C.RED
        print(
            f"  {C.CYAN}{d['id']:<12}{C.RESET}"
            f" {d['name']:<18}"
            f" {C.GRAY}{d['type']:<9}{C.RESET}"
            f" {status_c}{d['status']:<10}{C.RESET}"
            f" {str(d.get('rssi') or '—'):<8}"
            f" {d.get('msg_count', 0)}"
        )

    print()
    info(f"Total: {len(devices)} dispositivos")
    pause()


# ── 12. LIMPIAR LOGS ──────────────────────────────────────
def cmd_clear_logs():
    separator("Limpiar Logs")
    if not confirm("¿Borrar todos los archivos de log?"):
        return
    for f in LOG_DIR.glob("*.log"):
        f.unlink()
        dim(f"  Borrado: {f.name}")
    ok("Logs eliminados.")
    pause()


# ──────────────────────────────────────────────────────────
#  MENÚ PRINCIPAL
# ──────────────────────────────────────────────────────────
MENU_ITEMS = [
    # (tecla, etiqueta, función, categoría)
    ("s", "Arrancar servidor (background)",  lambda: cmd_start(False),    "server"),
    ("f", "Arrancar servidor (foreground)",  lambda: cmd_start(True),     "server"),
    ("k", "Detener servidor",                cmd_stop,                    "server"),
    ("r", "Reiniciar servidor",              cmd_restart,                 "server"),
    ("i", "Estado del sistema",              cmd_status,                  "server"),
    ("l", "Ver logs en vivo",                cmd_logs,                    "server"),
    ("─", None,                              None,                        None),
    ("1", "Instalar dependencias",           cmd_install,                 "setup"),
    ("2", "Crear entorno virtual (.venv)",   cmd_venv,                    "setup"),
    ("─", None,                              None,                        None),
    ("3", "Instalar servicio  (Linux/RPi)",  cmd_service_install,         "service"),
    ("5", "Gestionar servicio (Linux/RPi)",  cmd_service_manage,          "service"),
    ("4", "Tarea programada   (Windows)",    cmd_service_windows,         "service"),
    ("─", None,                              None,                        None),
    ("d", "Ver dispositivos (live)",         cmd_devices,                 "tools"),
    ("t", "Simular trama RF",                cmd_simulate_rf,             "tools"),
    ("x", "Limpiar logs",                    cmd_clear_logs,              "tools"),
    ("─", None,                              None,                        None),
    ("q", "Salir",                           None,                        None),
]


def print_menu():
    os.system("cls" if IS_WINDOWS else "clear")
    banner()

    # Estado rápido en el header
    print(f"  {C.BOLD}Servidor:{C.RESET} {server_status_str()}")
    print()
    separator("Menú Principal")
    print()

    categories = {
        "server":  ("🖥️ ", "Servidor"),
        "setup":   ("⚙️ ", "Configuración"),
        "service": ("🔧", "Servicios del sistema"),
        "tools":   ("🛠️ ", "Herramientas"),
    }
    current_cat = None

    for key, label, _, cat in MENU_ITEMS:
        if key == "─":
            print()
            continue

        if cat and cat != current_cat:
            current_cat = cat
            ico, name = categories.get(cat, ("", ""))
            print(f"  {C.GRAY}{ico} {name}{C.RESET}")

        if key == "q":
            print(f"  {C.GRAY}  [{key}]{C.RESET} {label}")
        else:
            print(f"  {C.CYAN}  [{key}]{C.RESET} {label}")

    print()
    separator()
    print()


def interactive_menu():
    action_map = {k: fn for k, label, fn, _ in MENU_ITEMS if k not in ("─",) and fn}

    while True:
        print_menu()
        try:
            choice = input(f"  {C.BOLD}Selecciona una opción:{C.RESET} ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print()
            ok("¡Hasta luego!")
            sys.exit(0)

        if choice == "q":
            print()
            ok("¡Hasta luego!")
            break

        fn = action_map.get(choice)
        if fn:
            print()
            fn()
        else:
            warn(f"Opción inválida: '{choice}'")
            time.sleep(0.6)


# ──────────────────────────────────────────────────────────
#  CLI DE ARGUMENTOS (modo no-interactivo)
# ──────────────────────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        prog="python run.py",
        description="IoT RF Gateway — Manager CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Comandos disponibles:
              start        Arrancar servidor en segundo plano
              start-fg     Arrancar servidor en primer plano
              stop         Detener servidor
              restart      Reiniciar servidor
              status       Ver estado del sistema
              logs         Ver logs en vivo
              install      Instalar dependencias
              venv         Crear entorno virtual
              service      Instalar servicio systemd (Linux)
              svc-manage   Submenú gestión del servicio systemd
              svc-start    Iniciar servicio systemd
              svc-stop     Detener servicio systemd
              svc-restart  Reiniciar servicio systemd
              svc-status   Estado del servicio systemd
              svc-logs     Logs en vivo del servicio (journalctl)
              devices      Listar dispositivos
              simulate     Simular trama RF
        """)
    )
    parser.add_argument("command", nargs="?", help="Comando a ejecutar")
    return parser.parse_args()


COMMAND_MAP = {
    "start":    lambda: cmd_start(False),
    "start-fg": lambda: cmd_start(True),
    "stop":     cmd_stop,
    "restart":  cmd_restart,
    "status":   cmd_status,
    "logs":     cmd_logs,
    "install":    cmd_install,
    "venv":        cmd_venv,
    "service":     lambda: cmd_service_install() if IS_LINUX else cmd_service_windows(),
    "svc-manage":  cmd_service_manage,
    "svc-start":   lambda: _systemctl("start")   if IS_LINUX else warn("Solo Linux"),
    "svc-stop":    lambda: _systemctl("stop")    if IS_LINUX else warn("Solo Linux"),
    "svc-restart": lambda: _systemctl("restart") if IS_LINUX else warn("Solo Linux"),
    "svc-status":  lambda: _print_service_status() or pause(),
    "svc-logs":    lambda: subprocess.run(["sudo","journalctl","-u",SERVICE_NAME,"-f","--no-pager","-n","60"]) if IS_LINUX else warn("Solo Linux"),
    "devices":     cmd_devices,
    "simulate":    cmd_simulate_rf,
}


# ──────────────────────────────────────────────────────────
#  ENTRY POINT
# ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    args = parse_args()

    if args.command:
        fn = COMMAND_MAP.get(args.command)
        if fn:
            banner()
            fn()
        else:
            err(f"Comando desconocido: '{args.command}'")
            print(f"  Comandos válidos: {', '.join(COMMAND_MAP)}")
            sys.exit(1)
    else:
        interactive_menu()
