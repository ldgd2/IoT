import os
import sys
import subprocess
from rich.console import Console
from rich.panel import Panel
import questionary
from scripts.utils.auth import authenticate_hub_cli, authenticate_server_cli

console = Console()

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def show_main_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold cyan][IoT Gateway & Servidor Puente - Orquestador Maestro][/bold cyan]", border_style="cyan"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una opcion de gestion:",
            choices=[
                "[HUB] Gestion del Central Hub (Red Local)",
                "[SERVER] Gestion del Servidor Colmena (Cloud/Bridge)",
                questionary.Separator(),
                "[TOOLS] Utilidades Generales (Red, Configuración, Compilación)",
                questionary.Separator(),
                "[EXIT] Salir"
            ],
            style=questionary.Style([
                ('qmark', 'fg:#673ab7 bold'),
                ('question', 'bold'),
                ('answer', 'fg:#f44336 bold'),
                ('pointer', 'fg:#00bcd4 bold'),
                ('highlighted', 'fg:#00bcd4 bold'),
                ('selected', 'fg:#cc5454'),
                ('separator', 'fg:#cc5454'),
            ])
        ).ask()
        
        if choice == "[EXIT] Salir" or choice is None:
            console.print("[green]Hasta luego![/green]")
            break
        elif choice.startswith("[HUB]"):
            show_hub_menu()
        elif choice.startswith("[SERVER]"):
            show_server_menu()
        elif choice.startswith("[TOOLS]"):
            show_utilities_menu()

def show_hub_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow][HUB] Gestion del Central Hub (Puerto 5000)[/bold yellow]", border_style="yellow"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una categoria:",
            choices=[
                "[SERVICE] Servicios (Iniciar, Detener, Logs)",
                "[DB] Base de Datos y Usuarios",
                "[DEVICES] Dispositivos y Estado de Red",
                questionary.Separator(),
                "[BACK] Volver al menu principal"
            ],
            style=questionary.Style([('pointer', 'fg:#ffc107 bold'), ('highlighted', 'fg:#ffc107 bold')])
        ).ask()

        if choice == "[BACK] Volver al menu principal" or choice is None:
            break
        elif choice.startswith("[SERVICE]"):
            show_hub_service_menu()
        elif choice.startswith("[DB]"):
            show_hub_db_menu()
        elif choice.startswith("[DEVICES]"):
            show_hub_devices_menu()

def show_server_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta][SERVER] Gestion del Servidor Colmena (Cloud / Puerto 8000)[/bold magenta]", border_style="magenta"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una categoria:",
            choices=[
                "[SERVICE] Servicios (Iniciar, Detener, Logs)",
                "[DB] Base de Datos y Administracion",
                "[NOTIF] Pruebas de Notificaciones Push",
                questionary.Separator(),
                "[BACK] Volver al menu principal"
            ],
            style=questionary.Style([('pointer', 'fg:#e91e63 bold'), ('highlighted', 'fg:#e91e63 bold')])
        ).ask()

        if choice == "[BACK] Volver al menu principal" or choice is None:
            break
        elif choice.startswith("[SERVICE]"):
            show_server_service_menu()
        elif choice.startswith("[DB]"):
            show_server_db_menu()
        elif choice.startswith("[NOTIF]"):
            show_server_notif_menu()

def show_utilities_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold green][TOOLS] Utilidades Generales[/bold green]", border_style="green"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una utilidad:",
            choices=[
                "[SCAN] Escaner de Red RF",
                "[ENV] Asistente de Configuracion (.env)",
                "[DEPS] Instalar Dependencias (VENV y PIP)",
                "[FW] Compilar Firmware C++",
                questionary.Separator(),
                "[BACK] Volver al menu principal"
            ]
        ).ask()
        
        if choice == "[BACK] Volver al menu principal" or choice is None:
            break
        elif choice.startswith("[SCAN]"):
            subprocess.run([sys.executable, "iot.py", "network", "scan"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("[ENV]"):
            subprocess.run([sys.executable, "iot.py", "setup", "env"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("[DEPS]"):
            subprocess.run([sys.executable, "iot.py", "setup", "install-deps"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("[FW]"):
            subprocess.run([sys.executable, "iot.py", "firmware", "wizard"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

# --- HUB SUBMENUS ---
def show_hub_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow][SERVICE] Servicios del Central Hub[/bold yellow]", border_style="yellow"))
        
        choice = questionary.select(
            "Selecciona una accion:",
            choices=[
                "[STATUS] Ver Estado, IP y Puerto de la Central Hub",
                "[START-FG] Arrancar Central Hub en Vivo (Foreground)",
                "[START-BG] Iniciar Central Hub en Segundo Plano (Background)",
                "[STOP] Detener Central Hub",
                "[RESTART] Reiniciar Central Hub",
                "[LOGS] Ver Logs en vivo (hub.log)",
                "[INSTALL] Instalar Servicio en Sistema (Linux/Systemd)",
                "[UNINSTALL] Eliminar y Limpiar Servicio de Central Hub",
                questionary.Separator(),
                "[BACK] Volver"
            ]
        ).ask()
        
        if choice == "[BACK] Volver" or choice is None: break
            
        cmds = {
            "[STATUS] Ver Estado, IP y Puerto de la Central Hub": ["iot.py", "hub", "service-status"],
            "[START-FG] Arrancar Central Hub en Vivo (Foreground)": ["iot.py", "hub", "start"],
            "[START-BG] Iniciar Central Hub en Segundo Plano (Background)": ["iot.py", "hub", "service-start"],
            "[STOP] Detener Central Hub": ["iot.py", "hub", "service-stop"],
            "[RESTART] Reiniciar Central Hub": ["iot.py", "hub", "service-restart"],
            "[LOGS] Ver Logs en vivo (hub.log)": ["iot.py", "hub", "service-logs"],
            "[INSTALL] Instalar Servicio en Sistema (Linux/Systemd)": ["iot.py", "hub", "service-install"],
            "[UNINSTALL] Eliminar y Limpiar Servicio de Central Hub": ["iot.py", "hub", "service-uninstall"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_hub_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow][DB] Base de Datos del Central Hub[/bold yellow]", border_style="yellow"))
        
        choice = questionary.select(
            "Selecciona una accion:",
            choices=[
                "[MIGRATE] Ejecutar Migraciones (Recursivo BaseModel)",
                "[USERS] Ver Usuarios Registrados",
                "[BACKUP] Crear Backup de BD",
                "[FORMAT] Formatear Base de Datos (Requiere Login)",
                questionary.Separator(),
                "[BACK] Volver"
            ]
        ).ask()
        
        if choice == "[BACK] Volver" or choice is None: break
        
        if choice.startswith("[MIGRATE]"):
            subprocess.run([sys.executable, "iot.py", "db", "hub", "migrate"])
        elif choice.startswith("[USERS]"):
            subprocess.run([sys.executable, "iot.py", "db", "hub", "users"])
        elif choice.startswith("[BACKUP]"):
            subprocess.run([sys.executable, "iot.py", "db", "backups", "create"])
        elif choice.startswith("[FORMAT]"):
            if authenticate_hub_cli():
                subprocess.run([sys.executable, "iot.py", "db", "hub", "format"])
        
        console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_hub_devices_menu():
    clear_screen()
    console.print(Panel.fit("[bold yellow][DEVICES] Dispositivos del Central Hub[/bold yellow]", border_style="yellow"))
    console.print("[dim]Funcionalidad en desarrollo para administrar equipos desde la CLI.[/dim]")
    console.input("\n[dim]Presiona Enter para continuar...[/dim]")

# --- SERVER SUBMENUS ---
def show_server_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta][SERVICE] Servicios del Servidor Colmena[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una accion:",
            choices=[
                "[STATUS] Ver Estado, IP y Puerto del Servidor",
                "[START-FG] Arrancar Servidor en Vivo (Foreground)",
                "[START-BG] Iniciar Servidor en Segundo Plano (Background)",
                "[STOP] Detener Servidor",
                "[RESTART] Reiniciar Servidor",
                "[LOGS] Ver Logs en vivo (bridge.log)",
                "[INSTALL] Instalar Servicio en Sistema (Linux Systemd / Windows Task)",
                "[UNINSTALL] Eliminar y Limpiar Servicio",
                questionary.Separator(),
                "[BACK] Volver"
            ]
        ).ask()
        
        if choice == "[BACK] Volver" or choice is None: break
            
        cmds = {
            "[STATUS] Ver Estado, IP y Puerto del Servidor": ["iot.py", "bridge", "service-status"],
            "[START-FG] Arrancar Servidor en Vivo (Foreground)": ["iot.py", "bridge", "start"],
            "[START-BG] Iniciar Servidor en Segundo Plano (Background)": ["iot.py", "bridge", "service-start"],
            "[STOP] Detener Servidor": ["iot.py", "bridge", "service-stop"],
            "[RESTART] Reiniciar Servidor": ["iot.py", "bridge", "service-restart"],
            "[LOGS] Ver Logs en vivo (bridge.log)": ["iot.py", "bridge", "service-logs"],
            "[INSTALL] Instalar Servicio en Sistema (Linux Systemd / Windows Task)": ["iot.py", "bridge", "service-install"],
            "[UNINSTALL] Eliminar y Limpiar Servicio": ["iot.py", "bridge", "service-uninstall"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_server_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta][DB] Base de Datos del Servidor Colmena[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una accion:",
            choices=[
                "[MIGRATE] Ejecutar Migraciones Automaticas",
                "[USERS] Ver Todos los Usuarios/Hubs (Requiere Root)",
                "[FORMAT] Formatear Base de Datos (Requiere Root)",
                questionary.Separator(),
                "[BACK] Volver"
            ]
        ).ask()
        
        if choice == "[BACK] Volver" or choice is None: break
        
        if choice.startswith("[MIGRATE]"):
            subprocess.run([sys.executable, "iot.py", "db", "server", "migrate"])
        elif choice.startswith("[USERS]"):
            if authenticate_server_cli():
                subprocess.run([sys.executable, "iot.py", "db", "server", "users"])
        elif choice.startswith("[FORMAT]"):
            if authenticate_server_cli():
                subprocess.run([sys.executable, "iot.py", "db", "server", "format"])
                
        console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_server_notif_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta][NOTIF] Herramientas de Notificaciones (Servidor)[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una accion:",
            choices=[
                "[TEST] Prueba de Notificacion (Test Push)",
                questionary.Separator(),
                "[BACK] Volver"
            ]
        ).ask()
        
        if choice == "[BACK] Volver" or choice is None: break
        
        if choice.startswith("[TEST]"):
            subprocess.run([sys.executable, "iot.py", "server-tools", "notif", "test"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
