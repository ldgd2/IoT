import os
import sys
import subprocess
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt

console = Console()

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def show_main_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold cyan]📡 IoT RF Gateway - Orquestador Maestro[/bold cyan]", border_style="cyan"))
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_row("[bold green][1][/bold green]", "🚀 Arrancar Servidor (Foreground)")
        table.add_row("[bold yellow][2][/bold yellow]", "🔧 Gestión de Servicios (Systemd / Background)")
        table.add_row("[bold magenta][3][/bold magenta]", "🗄️ Base de Datos (Migraciones y Backups)")
        table.add_row("[bold blue][4][/bold blue]", "🌐 Herramientas de Red (Escaner RF)")
        table.add_row("[bold red][q][/bold red]", "❌ Salir")
        
        console.print(table)
        console.print()
        choice = Prompt.ask("[bold cyan]Selecciona una opción[/bold cyan]", choices=['1', '2', '3', '4', 'q'])
        
        if choice == 'q':
            console.print("[green]¡Hasta luego![/green]")
            break
        elif choice == '1':
            subprocess.run([sys.executable, "iot.py", "admin", "start"])
        elif choice == '2':
            show_service_menu()
        elif choice == '3':
            show_db_menu()
        elif choice == '4':
            subprocess.run([sys.executable, "iot.py", "network", "scan"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_service_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold yellow]🔧 Gestión de Servicios Systemd[/bold yellow]", border_style="yellow"))
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_row("[bold green][s][/bold green]", "▶️ Iniciar servicio")
        table.add_row("[bold red][p][/bold red]", "⏹️ Detener servicio")
        table.add_row("[bold yellow][r][/bold yellow]", "🔄 Reiniciar servicio")
        table.add_row("[bold cyan][e][/bold cyan]", "ℹ️ Ver estado del servicio")
        table.add_row("[bold magenta][i][/bold magenta]", "📦 Instalar servicio")
        table.add_row("[bold blue][l][/bold blue]", "📜 Ver Logs en vivo (server.log)")
        table.add_row("[bold gray][b][/bold gray]", "⬅️ Volver al menú principal")
        
        console.print(table)
        console.print()
        choice = Prompt.ask("[bold yellow]Selecciona una opción[/bold yellow]", choices=['s', 'p', 'r', 'e', 'i', 'l', 'b'])
        
        if choice == 'b':
            break
        
        cmds = {
            's': ["iot.py", "admin", "service-start"],
            'p': ["iot.py", "admin", "service-stop"],
            'r': ["iot.py", "admin", "service-restart"],
            'e': ["iot.py", "admin", "service-status"],
            'i': ["iot.py", "admin", "service-install"],
            'l': ["iot.py", "admin", "service-logs"]
        }
        
        if choice in cmds:
            subprocess.run([sys.executable] + cmds[choice])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")

def show_db_menu():
    while True:
        clear_screen()
        console.print(Panel.fit("[bold magenta]🗄️ Gestión de Base de Datos[/bold magenta]", border_style="magenta"))
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_row("[bold green][1][/bold green]", "🔄 Ejecutar Migraciones (BaseModel)")
        table.add_row("[bold cyan][2][/bold cyan]", "📦 Crear Backup de BD")
        table.add_row("[bold gray][b][/bold gray]", "⬅️ Volver al menú principal")
        
        console.print(table)
        console.print()
        choice = Prompt.ask("[bold magenta]Selecciona una opción[/bold magenta]", choices=['1', '2', 'b'])
        
        if choice == 'b':
            break
        elif choice == '1':
            subprocess.run([sys.executable, "iot.py", "db", "migrate"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
        elif choice == '2':
            subprocess.run([sys.executable, "iot.py", "db", "backups", "create"])
            console.input("\n[dim]Presiona Enter para continuar...[/dim]")
