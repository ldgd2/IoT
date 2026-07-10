import rich_click as click
from rich.console import Console

console = Console()

@click.group()
def cli():
    """Orquestador Maestro IoT Gateway & Servidor Puente Colmena"""
    pass

from scripts.admin.cli import admin
from scripts.bridge.cli import bridge
from scripts.database.cli import db
from scripts.network.cli import network
from scripts.setup.cli import setup
from scripts.firmware.cli import firmware

# Registro de comandos principales y alias
cli.add_command(admin)
cli.add_command(admin, name="hub") # Alias explicito para la Central Hub (Puerto 5000)
cli.add_command(bridge)            # Gestor del Servidor Puente / Relay (Puerto 8000)
cli.add_command(db)
cli.add_command(network)
cli.add_command(setup)
cli.add_command(firmware)
