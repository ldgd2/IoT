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
@click.option("--title", default="Prueba de Notificacion", help="Titulo del push")
@click.option("--body", default="Este es un mensaje de prueba enviado desde el servidor Colmena.", help="Cuerpo del mensaje")
def notif_test(hub_id, title, body):
    """Envia una notificacion push de prueba a los usuarios de un Hub"""
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
        console.print("[yellow]No se encontraron usuarios para este Hub.[/yellow]")
        return

    console.print()
    console.print(Panel.fit(f"[bold]Enviando notificacion de prueba a {len(rows)} usuario(s)[/bold]", border_style="magenta"))
    console.print(f"  [bold]Titulo:[/bold] {title}")
    console.print(f"  [bold]Cuerpo:[/bold] {body}")
    console.print()

    sent = 0
    for row in rows:
        u = dict(row)
        user_id = u["user_id"]
        token_rows = sdb.execute(
            "SELECT DISTINCT fcm_token FROM ("
            "  SELECT fcm_token FROM users WHERE user_id = ? AND fcm_token != '' AND fcm_token IS NOT NULL "
            "  UNION "
            "  SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ? AND fcm_token != '' AND fcm_token IS NOT NULL"
            ")",
            (user_id, user_id)
        ).fetchall()
        tokens = [dict(t)["fcm_token"] for t in token_rows if dict(t).get("fcm_token")]

        if not tokens:
            console.print(f"  [yellow][WARN] Usuario '{u['username']}' sin token FCM (omitido).[/yellow]")
            continue

        try:
            from server.modules.notifications.fcm import send_push_notification
            for token in tokens:
                send_push_notification(token, title, body, data={"event": "test", "hub_id": hub_id})
            console.print(f"  [green][OK][/green] Notificacion enviada a {len(tokens)} dispositivo(s) de '{u['username']}'")
            sent += 1
        except Exception as e:
            console.print(f"  [red][ERROR] Error al enviar a '{u['username']}': {e}[/red]")

    console.print()
    console.print(f"[bold green]Resultado: {sent}/{len(rows)} notificaciones enviadas exitosamente.[/bold green]")
    console.print()

