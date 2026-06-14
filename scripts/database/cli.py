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
        BaseModel.migrate_all()
        
        progress.update(task, completed=100, description="[green]Migraciones aplicadas a todas las hijas exitosamente![/green]")

from scripts.database.backups.cli import backups
db.add_command(backups)
