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
from scripts.server_tools.cli import server_tools

# ─── Registro de comandos ───────────────────────────────────
cli.add_command(admin)
cli.add_command(admin, name="hub")         # Alias para el Hub (Puerto 5000)
cli.add_command(bridge)                    # Servidor Puente / Relay (Puerto 8000)
cli.add_command(bridge, name="server")     # Alias para el Servidor Cloud
cli.add_command(db)
cli.add_command(network)
cli.add_command(setup)
cli.add_command(firmware)
cli.add_command(server_tools)
