import click
import subprocess
import os
from pathlib import Path
from rich.console import Console

console = Console()
ROOT_DIR = Path(__file__).parent.parent.parent.resolve()

@click.group()
def firmware():
    """Gestión y Compilación de Firmware C++ (PlatformIO)"""
    pass

@firmware.command()
@click.argument('dispositivo', type=click.Choice(['lights', 'translator', 'all'], case_sensitive=False))
@click.option('--env', '-e', default='rp2040', help='Entorno de compilación (rp2040 o esp8266)')
def build(dispositivo, env):
    """Compila el firmware para un dispositivo específico"""
    targets = ['lights', 'translator'] if dispositivo == 'all' else [dispositivo]
    
    for t in targets:
        proj_dir = ROOT_DIR / "devices" / t
        console.print(f"[bold cyan]🔨 Compilando firmware para: {t} (Entorno: {env})[/bold cyan]")
        
        try:
            subprocess.run(["pio", "--version"], capture_output=True, check=True)
        except (FileNotFoundError, subprocess.CalledProcessError):
            console.print("[red]❌ Error: PlatformIO Core (pio) no está instalado o no está en el PATH.[/red]")
            console.print("[yellow]Instálalo usando: pip install platformio[/yellow]")
            return
            
        res = subprocess.run(["pio", "run", "-e", env], cwd=proj_dir)
        if res.returncode == 0:
            console.print(f"[green]✅ Compilación exitosa para {t}[/green]\n")
        else:
            console.print(f"[red]❌ Error compilando {t}[/red]\n")
