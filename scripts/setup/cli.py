import rich_click as click
import questionary
from rich.console import Console
from rich.panel import Panel
from server.core.config import ENV_FILE
from dotenv import dotenv_values
import os

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
    
    rf_port = questionary.text(
        "Puerto Serial RF (ej. /dev/ttyUSB0 o COM3) (RF_PORT):",
        default=current_env.get("RF_PORT", "/dev/ttyUSB0")
    ).ask()
    
    rf_baud = questionary.text(
        "Baudrate del Serial (RF_BAUD):",
        default=current_env.get("RF_BAUD", "9600")
    ).ask()
    
    # Confirmar escritura
    if not questionary.confirm("¿Guardar esta configuración en el archivo .env?").ask():
        console.print("[red]Configuración cancelada.[/red]")
        return
        
    with open(ENV_FILE, "w") as f:
        f.write(f"API_PORT={api_port}\n")
        f.write(f"RF_PORT={rf_port}\n")
        f.write(f"RF_BAUD={rf_baud}\n")
        
    console.print(f"\n[bold green]✅ Configuración guardada exitosamente en {ENV_FILE}[/bold green]")
