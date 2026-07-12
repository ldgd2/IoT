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
        console.print(Panel.fit("[bold cyan]📡 IoT RF Gateway & Servidor Puente - Orquestador Maestro[/bold cyan]", border_style="cyan"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una opción de gestión:",
            choices=[
                "🏢 Gestión del Central Hub (Red Local)",
                "☁️ Gestión del Servidor Colmena (Cloud/Bridge)",
                questionary.Separator(),
                "🛠️ Utilidades Generales (Red, Configuración, Compilación)",
                questionary.Separator(),
                "❌ Salir"
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
        
        if choice == "❌ Salir" or choice is None:
            console.print("[green]¡Hasta luego![/green]")
            break
        elif choice.startswith("🏢"):
            show_hub_menu()
        elif choice.startswith("☁️"):
            show_server_menu()
        elif choice.startswith("🛠️"):
            show_utilities_menu()

def show_hub_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]🏢 Gestión del Central Hub (Puerto 5000)[/bold yellow]", border_style="yellow"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una categoría:",
            choices=[
                "⚙️ Servicios (Iniciar, Detener, Logs)",
                "🗄️ Base de Datos y Usuarios",
                "🔌 Dispositivos y Estado de Red",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ],
            style=questionary.Style([('pointer', 'fg:#ffc107 bold'), ('highlighted', 'fg:#ffc107 bold')])
        ).ask()

        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
        elif choice.startswith("⚙️"):
            show_hub_service_menu()
        elif choice.startswith("🗄️"):
            show_hub_db_menu()
        elif choice.startswith("🔌"):
            show_hub_devices_menu()

def show_server_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]☁️ Gestión del Servidor Colmena (Cloud / Puerto 8000)[/bold magenta]", border_style="magenta"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una categoría:",
            choices=[
                "⚙️ Servicios (Iniciar, Detener, Logs)",
                "🗄️ Base de Datos y Administración",
                "🔔 Pruebas de Notificaciones Push",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ],
            style=questionary.Style([('pointer', 'fg:#e91e63 bold'), ('highlighted', 'fg:#e91e63 bold')])
        ).ask()

        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
        elif choice.startswith("⚙️"):
            show_server_service_menu()
        elif choice.startswith("🗄️"):
            show_server_db_menu()
        elif choice.startswith("🔔"):
            show_server_notif_menu()

def show_utilities_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold green]🛠️ Utilidades Generales[/bold green]", border_style="green"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una utilidad:",
            choices=[
                "🌐 Escáner de Red RF",
                "⚙️ Asistente de Configuración (.env)",
                "🛠️ Instalar Dependencias (VENV y PIP)",
                "🔨 Compilar Firmware C++",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ]
        ).ask()
        
        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
        elif choice.startswith("🌐"):
            subprocess.run([sys.executable, "iot.py", "network", "scan"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("⚙️"):
            subprocess.run([sys.executable, "iot.py", "setup", "env"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("🛠️"):
            subprocess.run([sys.executable, "iot.py", "setup", "install-deps"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("🔨"):
            subprocess.run([sys.executable, "iot.py", "firmware", "wizard"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

# --- HUB SUBMENUS ---
def show_hub_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]⚙️ Servicios del Central Hub[/bold yellow]", border_style="yellow"))
        
        choice = questionary.select(
            "Selecciona una acción:",
            choices=[
                "ℹ️ Ver Estado, IP y Puerto de la Central Hub",
                "🚀 Arrancar Central Hub en Vivo (Foreground)",
                "▶️ Iniciar Central Hub en Segundo Plano (Background)",
                "⏹️ Detener Central Hub",
                "🔄 Reiniciar Central Hub",
                "📜 Ver Logs en vivo (hub.log)",
                "📦 Instalar Servicio en Sistema (Linux/Systemd)",
                "🗑️ Eliminar y Limpiar Servicio de Central Hub",
                questionary.Separator(),
                "⬅️ Volver"
            ]
        ).ask()
        
        if choice == "⬅️ Volver" or choice is None: break
            
        cmds = {
            "ℹ️ Ver Estado, IP y Puerto de la Central Hub": ["iot.py", "hub", "service-status"],
            "🚀 Arrancar Central Hub en Vivo (Foreground)": ["iot.py", "hub", "start"],
            "▶️ Iniciar Central Hub en Segundo Plano (Background)": ["iot.py", "hub", "service-start"],
            "⏹️ Detener Central Hub": ["iot.py", "hub", "service-stop"],
            "🔄 Reiniciar Central Hub": ["iot.py", "hub", "service-restart"],
            "📜 Ver Logs en vivo (hub.log)": ["iot.py", "hub", "service-logs"],
            "📦 Instalar Servicio en Sistema (Linux/Systemd)": ["iot.py", "hub", "service-install"],
            "🗑️ Eliminar y Limpiar Servicio de Central Hub": ["iot.py", "hub", "service-uninstall"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_hub_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]🗄️ Base de Datos del Central Hub[/bold yellow]", border_style="yellow"))
        
        choice = questionary.select(
            "Selecciona una acción:",
            choices=[
                "🔄 Ejecutar Migraciones (Recursivo BaseModel)",
                "👥 Ver Usuarios Registrados",
                "📦 Crear Backup de BD",
                "❌ Formatear Base de Datos (Requiere Login)",
                questionary.Separator(),
                "⬅️ Volver"
            ]
        ).ask()
        
        if choice == "⬅️ Volver" or choice is None: break
        
        if choice.startswith("🔄"):
            subprocess.run([sys.executable, "iot.py", "db", "hub", "migrate"])
        elif choice.startswith("👥"):
            subprocess.run([sys.executable, "iot.py", "db", "hub", "users"])
        elif choice.startswith("📦"):
            subprocess.run([sys.executable, "iot.py", "db", "backups", "create"])
        elif choice.startswith("❌"):
            if authenticate_hub_cli():
                subprocess.run([sys.executable, "iot.py", "db", "hub", "format"])
        
        console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_hub_devices_menu():
    clear_screen()
    console.print(Panel.fit("[bold yellow]🔌 Dispositivos del Central Hub[/bold yellow]", border_style="yellow"))
    console.print("[dim]Funcionalidad en desarrollo para administrar equipos desde la CLI.[/dim]")
    console.input("\n[dim]Presiona Enter para continuar...[/dim]")

# --- SERVER SUBMENUS ---
def show_server_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]⚙️ Servicios del Servidor Colmena[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una acción:",
            choices=[
                "ℹ️ Ver Estado, IP y Puerto del Servidor",
                "🚀 Arrancar Servidor en Vivo (Foreground)",
                "▶️ Iniciar Servidor en Segundo Plano (Background)",
                "⏹️ Detener Servidor",
                "🔄 Reiniciar Servidor",
                "📜 Ver Logs en vivo (bridge.log)",
                "📦 Instalar Servicio en Sistema (Linux Systemd / Windows Task)",
                "🗑️ Eliminar y Limpiar Servicio",
                questionary.Separator(),
                "⬅️ Volver"
            ]
        ).ask()
        
        if choice == "⬅️ Volver" or choice is None: break
            
        cmds = {
            "ℹ️ Ver Estado, IP y Puerto del Servidor": ["iot.py", "bridge", "service-status"],
            "🚀 Arrancar Servidor en Vivo (Foreground)": ["iot.py", "bridge", "start"],
            "▶️ Iniciar Servidor en Segundo Plano (Background)": ["iot.py", "bridge", "service-start"],
            "⏹️ Detener Servidor": ["iot.py", "bridge", "service-stop"],
            "🔄 Reiniciar Servidor": ["iot.py", "bridge", "service-restart"],
            "📜 Ver Logs en vivo (bridge.log)": ["iot.py", "bridge", "service-logs"],
            "📦 Instalar Servicio en Sistema (Linux Systemd / Windows Task)": ["iot.py", "bridge", "service-install"],
            "🗑️ Eliminar y Limpiar Servicio": ["iot.py", "bridge", "service-uninstall"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_server_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]🗄️ Base de Datos del Servidor Colmena[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una acción:",
            choices=[
                "🔄 Ejecutar Migraciones Automáticas",
                "👥 Ver Todos los Usuarios/Hubs (Requiere Root)",
                "❌ Formatear Base de Datos (Requiere Root)",
                questionary.Separator(),
                "⬅️ Volver"
            ]
        ).ask()
        
        if choice == "⬅️ Volver" or choice is None: break
        
        if choice.startswith("🔄"):
            subprocess.run([sys.executable, "iot.py", "db", "server", "migrate"])
        elif choice.startswith("👥"):
            if authenticate_server_cli():
                subprocess.run([sys.executable, "iot.py", "db", "server", "users"])
        elif choice.startswith("❌"):
            if authenticate_server_cli():
                subprocess.run([sys.executable, "iot.py", "db", "server", "format"])
                
        console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_server_notif_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]🔔 Herramientas de Notificaciones (Servidor)[/bold magenta]", border_style="magenta"))
        
        choice = questionary.select(
            "Selecciona una acción:",
            choices=[
                "🧪 Prueba de Notificación (Test Push)",
                questionary.Separator(),
                "⬅️ Volver"
            ]
        ).ask()
        
        if choice == "⬅️ Volver" or choice is None: break
        
        if choice.startswith("🧪"):
            subprocess.run([sys.executable, "iot.py", "server-tools", "notif", "test"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
