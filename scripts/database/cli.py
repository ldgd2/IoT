import rich_click as click
import subprocess
import sys
import os
from pathlib import Path
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.table import Table
import time

console = Console()

# ──────────────────────────────────────────────
# Grupo raíz: db
# ──────────────────────────────────────────────
@click.group()
def db():
    """Gestión de base de datos (Hub y Servidor)"""
    pass


# ══════════════════════════════════════════════
# SUBGRUPO: db hub
# ══════════════════════════════════════════════
@db.group(name="hub")
def db_hub():
    """Herramientas de BD del Central Hub (SQLite local)"""
    pass

@db_hub.command(name="migrate")
def hub_migrate():
    """Ejecuta migraciones automáticas con búsqueda recursiva de modelos (BaseModel)"""
    console.print()
    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("[cyan]Importando modelos y descubriendo subclases...", total=None)
        time.sleep(0.8)

        # Importar todos los modelos para registrarlos en el árbol de subclases
        from hub.modules.auth.models.user import User
        from hub.modules.auth.models.room import Room
        try:
            from hub.modules.devices.models.device import Device
        except ImportError:
            pass
        try:
            from hub.modules.communication.models.rflog import RFLog
        except ImportError:
            pass
        try:
            from hub.modules.automation.models.skill import Skill
        except ImportError:
            pass

        from hub.db.database import BaseModel
        progress.update(task, description="[cyan]Aplicando migraciones a todas las tablas detectadas...")
        time.sleep(0.5)

        report = BaseModel.migrate_all()
        progress.update(task, completed=100, description="[green]✔ Migraciones completadas")

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


@db_hub.command(name="users")
def hub_users():
    """Lista los usuarios registrados en la BD local del Hub (dueños del Hub)"""
    from hub.modules.auth.models.user import User
    from hub.db.database import Database

    try:
        rows = Database.execute("SELECT user_id, username, email, created_at FROM users").fetchall()
    except Exception as e:
        console.print(f"[red]Error al consultar usuarios: {e}[/red]")
        return

    if not rows:
        console.print("[yellow]No hay usuarios registrados en la BD del Hub.[/yellow]")
        return

    table = Table(title="👥 Usuarios del Central Hub", show_header=True, header_style="bold yellow")
    table.add_column("#", style="dim", width=4)
    table.add_column("Username", style="bold")
    table.add_column("Email", style="cyan")
    table.add_column("Registrado", style="dim")

    for i, row in enumerate(rows, 1):
        r = dict(row)
        table.add_row(str(i), r.get("username", ""), r.get("email", ""), r.get("created_at", "")[:19])

    console.print()
    console.print(table)
    console.print()


@db_hub.command(name="init")
def hub_init():
    """Inicializa la BD del Hub (crea tablas si no existen sin borrar datos)"""
    hub_migrate.callback()


@db_hub.command(name="format")
def hub_format():
    """⚠️  DESTRUCTIVO: Elimina y recrea la BD del Hub. Requiere doble confirmación."""
    from hub.core.config import DB_FILE

    console.print("[bold red]⚠️  ADVERTENCIA: Esta operación eliminará TODOS los datos del Hub.[/bold red]")
    console.print(f"[dim]Archivo objetivo: {DB_FILE}[/dim]")
    console.print()

    confirm1 = click.prompt("Escribe 'FORMATEAR' para confirmar", default="")
    if confirm1 != "FORMATEAR":
        console.print("[yellow]Operación cancelada.[/yellow]")
        return

    confirm2 = click.prompt("¿Estás completamente seguro? Escribe 'SI' para continuar", default="")
    if confirm2 != "SI":
        console.print("[yellow]Operación cancelada.[/yellow]")
        return

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("[red]Eliminando base de datos del Hub...", total=None)
        time.sleep(0.5)

        if DB_FILE.exists():
            DB_FILE.unlink()
            progress.update(task, description="[yellow]Base de datos eliminada. Aplicando migraciones limpias...")
            time.sleep(0.5)

        # Re-importar modelos y migrar
        from hub.modules.auth.models.user import User
        from hub.modules.auth.models.room import Room
        try:
            from hub.modules.devices.models.device import Device
        except ImportError:
            pass
        try:
            from hub.modules.communication.models.rflog import RFLog
        except ImportError:
            pass
        from hub.db.database import BaseModel
        BaseModel.migrate_all()
        progress.update(task, completed=100, description="[green]✔ Base de datos del Hub formateada y lista")

    console.print("[bold green]✔ Operación completada. BD del Hub limpia y vacía.[/bold green]")
    console.print()


# ══════════════════════════════════════════════
# SUBGRUPO: db server
# ══════════════════════════════════════════════
@db.group(name="server")
def db_server():
    """Herramientas de BD del Servidor Colmena (SQLite server.sqlite)"""
    pass


@db_server.command(name="migrate")
def server_migrate():
    """Ejecuta migraciones automáticas del Servidor (ensure_tables)"""
    console.print()
    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("[magenta]Ejecutando ensure_tables() del servidor...", total=None)
        time.sleep(0.5)

        from server.db.database import ensure_tables
        ensure_tables()

        progress.update(task, completed=100, description="[green]✔ Tablas del servidor verificadas/creadas")

    console.print("[bold green]✔ Migraciones del servidor completadas.[/bold green]")
    console.print()


@db_server.command(name="users")
def server_users():
    """Lista usuarios y Hubs registrados en el Servidor Colmena"""
    from server.db import database as sdb

    try:
        users = sdb.execute("SELECT user_id, username, email, created_at FROM users").fetchall()
        hubs  = sdb.execute("SELECT hub_id, user_id, name, online, last_seen FROM hubs").fetchall()
    except Exception as e:
        console.print(f"[red]Error al consultar el servidor: {e}[/red]")
        return

    # Tabla de usuarios
    ut = Table(title="👥 Usuarios del Servidor", show_header=True, header_style="bold magenta")
    ut.add_column("#", style="dim", width=4)
    ut.add_column("Username", style="bold")
    ut.add_column("Email", style="cyan")
    ut.add_column("Registrado", style="dim")
    for i, row in enumerate(users, 1):
        r = dict(row)
        ut.add_row(str(i), r.get("username",""), r.get("email",""), r.get("created_at","")[:19])

    # Tabla de Hubs
    ht = Table(title="🏢 Hubs Registrados", show_header=True, header_style="bold yellow")
    ht.add_column("#", style="dim", width=4)
    ht.add_column("Hub ID", style="dim")
    ht.add_column("Nombre", style="bold")
    ht.add_column("Online", style="green")
    ht.add_column("Último Visto", style="dim")
    for i, row in enumerate(hubs, 1):
        r = dict(row)
        online = "[green]🟢[/green]" if r.get("online") else "[red]🔴[/red]"
        ht.add_row(str(i), r.get("hub_id","")[:8]+"...", r.get("name",""), online, (r.get("last_seen") or "—")[:19])

    console.print()
    console.print(ut)
    console.print()
    console.print(ht)
    console.print()


@db_server.command(name="init")
def server_init():
    """Inicializa la BD del Servidor (crea tablas sin borrar datos)"""
    server_migrate.callback()


@db_server.command(name="format")
def server_format():
    """⚠️  DESTRUCTIVO: Elimina y recrea la BD del Servidor. Requiere doble confirmación."""
    from pathlib import Path

    # Obtener ruta del db del server
    server_dir = Path(__file__).parent.parent.parent / "server" / "db"
    db_file = server_dir / "server.sqlite"

    console.print("[bold red]⚠️  ADVERTENCIA: Esta operación eliminará TODOS los datos del Servidor.[/bold red]")
    console.print(f"[dim]Archivo objetivo: {db_file}[/dim]")
    console.print()

    confirm1 = click.prompt("Escribe 'FORMATEAR' para confirmar", default="")
    if confirm1 != "FORMATEAR":
        console.print("[yellow]Operación cancelada.[/yellow]")
        return

    confirm2 = click.prompt("¿Estás completamente seguro? Escribe 'SI' para continuar", default="")
    if confirm2 != "SI":
        console.print("[yellow]Operación cancelada.[/yellow]")
        return

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("[red]Eliminando base de datos del Servidor...", total=None)
        time.sleep(0.5)

        if db_file.exists():
            db_file.unlink()
            progress.update(task, description="[yellow]BD eliminada. Aplicando tablas de nuevo...")
            time.sleep(0.5)

        from server.db.database import ensure_tables
        ensure_tables()
        progress.update(task, completed=100, description="[green]✔ Base de datos del Servidor formateada y lista")

    console.print("[bold green]✔ Operación completada. BD del Servidor limpia y vacía.[/bold green]")
    console.print()


# Backups (compatible con el sistema anterior)
from scripts.database.backups.cli import backups
db.add_command(backups)
