import click
from rich.console import Console

console = Console()

@click.group()
def cli():
    """Orquestador Maestro IoT Gateway"""
    pass

from scripts.admin.cli import admin
from scripts.database.cli import db
from scripts.network.cli import network

cli.add_command(admin)
cli.add_command(db)
cli.add_command(network)
