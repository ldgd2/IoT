import questionary
from rich.console import Console

console = Console()

def authenticate_hub_cli() -> bool:
    """Solicita credenciales en CLI para acciones sensibles del Hub."""
    console.print("[bold cyan]🔒 Autenticación requerida para herramientas del Hub[/bold cyan]")
    username = questionary.text("Usuario o Correo:").ask()
    if not username: return False
    password = questionary.password("Contraseña:").ask()
    if not password: return False

    from hub.modules.auth.models.user import User
    user = User.get_by_username_or_email(username)
    
    if user and user.verify_password(password):
        console.print("[bold green]✔ Acceso concedido.[/bold green]")
        return True
    
    console.print("[bold red]❌ Credenciales inválidas.[/bold red]")
    return False

def authenticate_server_cli() -> bool:
    """Solicita credenciales en CLI para acciones sensibles del Servidor."""
    console.print("[bold magenta]🔒 Autenticación ROOT requerida para el Servidor[/bold magenta]")
    
    # En un entorno real, habría una cuenta 'root' en el server o se leería del .env.
    # Por ahora, podemos usar el sistema de autenticación del server si existe, o pedir una pass maestra en .env.
    import os
    from dotenv import load_dotenv
    load_dotenv()
    
    master_pass = os.environ.get("SERVER_ROOT_PASSWORD", "colmena_root_123")
    
    password = questionary.password("Contraseña Root del Servidor:").ask()
    if not password: return False
    
    if password == master_pass:
        console.print("[bold green]✔ Acceso ROOT concedido.[/bold green]")
        return True
    
    console.print("[bold red]❌ Contraseña incorrecta.[/bold red]")
    return False
