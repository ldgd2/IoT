import rich_click as click
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
import time

console = Console()

@click.group()
def db():
    """Gestion de la base de datos (Migraciones, Backups)"""
    pass

@db.command()
def migrate():
    """Ejecuta migraciones automaticas sobre la BD (Arquitectura Padre)"""
    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("[cyan]Ejecutando introspección de modelos SQLite...", total=None)
        time.sleep(1) # Simular carga para la animacion
        
        # Import models so they register
        from server.modules.devices.models.device import Device
        from server.modules.communication.models.rflog import RFLog
        from server.modules.automation.models.skill import Skill
        from server.db.database import BaseModel
        
        # El padre aplica la migracion a todas las hijas
        report = BaseModel.migrate_all()
        
        progress.update(task, completed=100, description="[green]Migraciones finalizadas[/green]")

    # Print report
    console.print()
    if report["created"]:
        console.print("[bold green]Nuevas tablas creadas:[/bold green]")
        for table in report["created"]:
            console.print(f"  [green]✔[/green] {table}")
    
    if report["exists"]:
        console.print("[bold cyan]Tablas ya existentes (omitidas):[/bold cyan]")
        for table in report["exists"]:
            console.print(f"  [cyan]•[/cyan] {table}")
            
    if not report["created"] and not report["exists"]:
        console.print("[yellow]No se detectaron modelos para migrar.[/yellow]")
    console.print()

from scripts.database.backups.cli import backups
db.add_command(backups)
