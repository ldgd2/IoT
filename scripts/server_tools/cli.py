import rich_click as click
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt

console = Console()

@click.group(name="server-tools")
def server_tools():
    """Herramientas del Servidor Colmena (Notificaciones, Estado, etc.)"""
    pass

@server_tools.group(name="notif")
def notif():
    """Herramientas de notificaciones push (FCM)"""
    pass

@notif.command(name="test")
@click.option("--hub-id", default=None, help="Hub ID destino (opcional, usa el primero registrado si no se indica)")
@click.option("--title", default="🔔 Prueba de Notificación", help="Título del push")
@click.option("--body", default="Este es un mensaje de prueba enviado desde el servidor Colmena.", help="Cuerpo del mensaje")
def notif_test(hub_id, title, body):
    """Envía una notificación push de prueba a los usuarios de un Hub"""
    from server.db import database as sdb

    # Si no hay hub_id, intentar obtener el primero registrado
    if not hub_id:
        row = sdb.execute("SELECT hub_id, name FROM hubs LIMIT 1").fetchone()
        if not row:
            console.print("[red]No hay Hubs registrados en el Servidor. Registra un Hub primero.[/red]")
            return
        hub_id = dict(row)["hub_id"]
        console.print(f"[dim]Usando Hub por defecto: {hub_id[:8]}... ({dict(row)['name']})[/dim]")

    # Obtener usuarios del hub con token FCM
    rows = sdb.execute(
        "SELECT u.user_id, u.username, u.fcm_token FROM users u "
        "JOIN hubs h ON u.user_id = h.user_id WHERE h.hub_id = ?",
        (hub_id,)
    ).fetchall()

    if not rows:
        console.print("[yellow]No se encontraron usuarios/tokens FCM para este Hub.[/yellow]")
        return

    console.print()
    console.print(Panel.fit(f"[bold]📤 Enviando notificación de prueba a {len(rows)} usuario(s)[/bold]", border_style="magenta"))
    console.print(f"  [bold]Título:[/bold] {title}")
    console.print(f"  [bold]Cuerpo:[/bold] {body}")
    console.print()

    sent = 0
    for row in rows:
        u = dict(row)
        fcm_token = u.get("fcm_token", "")
        if not fcm_token:
            console.print(f"  [yellow]⚠️  Usuario '{u['username']}' sin token FCM (omitido).[/yellow]")
            continue

        try:
            from server.modules.notifications.fcm import send_push_notification
            send_push_notification(fcm_token, title, body, data={"event": "test", "hub_id": hub_id})
            console.print(f"  [green]✔[/green] Notificación enviada a '{u['username']}'")
            sent += 1
        except Exception as e:
            console.print(f"  [red]✗ Error al enviar a '{u['username']}': {e}[/red]")

    console.print()
    console.print(f"[bold green]Resultado: {sent}/{len(rows)} notificaciones enviadas exitosamente.[/bold green]")
    console.print()
