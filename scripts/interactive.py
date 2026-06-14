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
        console.print(Panel.fit("[bold cyan]📡 IoT RF Gateway - Orquestador Maestro[/bold cyan]", border_style="cyan"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una opción:",
            choices=[
                "🚀 Arrancar Servidor (Foreground)",
                "🔧 Gestión de Servicios (Systemd / Background)",
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
        elif choice.startswith("🚀"):
            subprocess.run([sys.executable, "iot.py", "admin", "start"])
        elif choice.startswith("🔧"):
            show_service_menu()
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

def show_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]🔧 Gestión de Servicios Systemd[/bold yellow]", border_style="yellow"))
        console.print()
        
        choice = questionary.select(
            "Selecciona una opción:",
            choices=[
                "▶️ Iniciar servicio",
                "⏹️ Detener servicio",
                "🔄 Reiniciar servicio",
                "ℹ️ Ver estado del servicio",
                "📜 Ver Logs en vivo (server.log)",
                "📦 Instalar servicio",
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
            "▶️ Iniciar servicio": ["iot.py", "admin", "service-start"],
            "⏹️ Detener servicio": ["iot.py", "admin", "service-stop"],
            "🔄 Reiniciar servicio": ["iot.py", "admin", "service-restart"],
            "ℹ️ Ver estado del servicio": ["iot.py", "admin", "service-status"],
            "📜 Ver Logs en vivo (server.log)": ["iot.py", "admin", "service-logs"],
            "📦 Instalar servicio": ["iot.py", "admin", "service-install"]
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
