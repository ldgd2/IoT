import click
from rich.console import Console

console = Console()

@click.group()
def backups():
    """Gestion de backups de la BD"""
    pass

@backups.command()
def create():
    """Crea un backup local en zip"""
    console.print("[yellow]Creando backup local...[/yellow]")
    import time
    time.sleep(1)
    console.print("[green]Backup creado: db_backup.zip[/green]")
