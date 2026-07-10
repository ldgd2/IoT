import os
import sys
import subprocess
from rich.console import Console
from rich.panel import Panel
import questionary

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
                "🏢 Gestión de Servicios Central Hub (Puerto 5000)",
                "🌉 Gestión de Servicios Servidor Puente (Puerto 8000)",
                questionary.Separator(),
                "🚀 Arrancar Central Hub en Vivo (Foreground)",
                "🚀 Arrancar Servidor Puente en Vivo (Foreground)",
                questionary.Separator(),
                "🗄️ Base de Datos (Migraciones y Backups)",
                "🌐 Herramientas de Red (Escaner RF)",
                "⚙️ Asistente de Configuración (.env)",
                "🛠️ Instalar Dependencias (VENV y PIP)",
                "🔨 Compilar Firmware C++",
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
            show_hub_service_menu()
        elif choice.startswith("🌉"):
            show_bridge_service_menu()
        elif choice == "🚀 Arrancar Central Hub en Vivo (Foreground)":
            subprocess.run([sys.executable, "iot.py", "hub", "start"])
        elif choice == "🚀 Arrancar Servidor Puente en Vivo (Foreground)":
            subprocess.run([sys.executable, "iot.py", "bridge", "start"])
        elif choice.startswith("🗄️"):
            show_db_menu()
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

def show_hub_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]🏢 Gestión del Servicio Central Hub (Puerto 5000)[/bold yellow]", border_style="yellow"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una acción para el Central Hub:",
            choices=[
                "ℹ️ Ver Estado, IP y Puerto de la Central Hub",
                "▶️ Iniciar Central Hub en Segundo Plano (Background)",
                "⏹️ Detener Central Hub",
                "🔄 Reiniciar Central Hub",
                "📜 Ver Logs en vivo (hub.log)",
                "📦 Instalar Servicio en Sistema (Linux/Systemd)",
                "🗑️ Eliminar y Limpiar Servicio de Central Hub",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ],
            style=questionary.Style([
                ('pointer', 'fg:#ffc107 bold'),
                ('highlighted', 'fg:#ffc107 bold'),
            ])
        ).ask()
        
        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
            
        cmds = {
            "ℹ️ Ver Estado, IP y Puerto de la Central Hub": ["iot.py", "hub", "service-status"],
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

def show_bridge_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]🌉 Gestión del Servidor Puente / Relay (Puerto 8000)[/bold magenta]", border_style="magenta"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una acción para el Servidor Puente:",
            choices=[
                "ℹ️ Ver Estado, IP y Puerto del Servidor Puente",
                "▶️ Iniciar Servidor Puente en Segundo Plano (Background)",
                "⏹️ Detener Servidor Puente",
                "🔄 Reiniciar Servidor Puente",
                "📜 Ver Logs en vivo (bridge.log)",
                "📦 Instalar Servicio en Sistema (Linux Systemd / Windows Task)",
                "🗑️ Eliminar y Limpiar Servicio de Servidor Puente",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ],
            style=questionary.Style([
                ('pointer', 'fg:#e91e63 bold'),
                ('highlighted', 'fg:#e91e63 bold'),
            ])
        ).ask()
        
        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
            
        cmds = {
            "ℹ️ Ver Estado, IP y Puerto del Servidor Puente": ["iot.py", "bridge", "service-status"],
            "▶️ Iniciar Servidor Puente en Segundo Plano (Background)": ["iot.py", "bridge", "service-start"],
            "⏹️ Detener Servidor Puente": ["iot.py", "bridge", "service-stop"],
            "🔄 Reiniciar Servidor Puente": ["iot.py", "bridge", "service-restart"],
            "📜 Ver Logs en vivo (bridge.log)": ["iot.py", "bridge", "service-logs"],
            "📦 Instalar Servicio en Sistema (Linux Systemd / Windows Task)": ["iot.py", "bridge", "service-install"],
            "🗑️ Eliminar y Limpiar Servicio de Servidor Puente": ["iot.py", "bridge", "service-uninstall"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]🗄️ Gestión de Base de Datos[/bold magenta]", border_style="magenta"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una opción:",
            choices=[
                "🔄 Ejecutar Migraciones (BaseModel)",
                "📦 Crear Backup de BD",
                questionary.Separator(),
                "⬅️ Volver al menú principal"
            ],
            style=questionary.Style([
                ('pointer', 'fg:#e91e63 bold'),
                ('highlighted', 'fg:#e91e63 bold'),
            ])
        ).ask()
        
        if choice == "⬅️ Volver al menú principal" or choice is None:
            break
        elif choice.startswith("🔄"):
            subprocess.run([sys.executable, "iot.py", "db", "migrate"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice.startswith("📦"):
            subprocess.run([sys.executable, "iot.py", "db", "backups", "create"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
