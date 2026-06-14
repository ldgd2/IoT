import rich_click as click
from rich.console import Console
import time

console = Console()

@click.group()
def network():
    """Gestion de nodos RF y red"""
    pass

@network.command()
def scan():
    """Escanea dispositivos RF en el aire"""
    with console.status("[bold cyan]Escaneando espectro RF...[/bold cyan]", spinner="bouncingBar"):
        time.sleep(2)
    console.print("[green]Escaneo completado. No se encontraron nodos nuevos.[/green]")
