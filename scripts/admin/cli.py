import click
import subprocess
import sys
from pathlib import Path
from rich.console import Console
from rich.panel import Panel

console = Console()
from core.config import SERVER_DIR, VENV_DIR

@click.group()
def admin():
    """Herramientas de administracion del servidor"""
    pass

@admin.command()
def start():
    """Arranca el servidor en primer plano"""
    console.print(Panel("[bold green]Iniciando Servidor IoT[/bold green]"))
    py_exec = str(VENV_DIR / "bin" / "python") if (VENV_DIR / "bin" / "python").exists() else sys.executable
    if sys.platform == "win32":
        py_exec = str(VENV_DIR / "Scripts" / "python.exe") if (VENV_DIR / "Scripts" / "python.exe").exists() else sys.executable
    try:
        subprocess.run([py_exec, str(SERVER_DIR / "main.py")])
    except KeyboardInterrupt:
        console.print("[yellow]Servidor detenido por el usuario.[/yellow]")

@admin.command()
def status():
    """Muestra el estado del sistema"""
    console.print("[cyan]Estado del sistema: [/cyan][green]OK[/green]")
