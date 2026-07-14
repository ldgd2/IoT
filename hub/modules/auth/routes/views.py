"""
hub/modules/auth/routes/views.py
Rutas web (UI) para autenticación del Hub local.
"""
from flask import Blueprint, render_template, request, session, redirect
import os
import requests
from hub.modules.auth.models.user import User

auth_view_bp = Blueprint("auth_view", __name__)

def _get_vps_url():
    vps_url = os.environ.get("CLOUD_SERVER_URL") or os.environ.get("CLOUD_BRIDGE_URL", "http://157.173.102.129:8000")
    vps_url = vps_url.rstrip("/")
    if vps_url.endswith("/api"):
        vps_url = vps_url[:-4]
    return vps_url.rstrip("/") + "/api"

def _auto_link_with_vps(vps_url, token, identifier):
    if not os.environ.get("HUB_ID") and token:
        try:
            hub_name = os.environ.get("HUB_NAME", "Central Colmena Hub")
            reg_headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
            reg_r = requests.post(f"{vps_url}/hubs", json={"name": hub_name, "local_url": "http://127.0.0.1:5000"}, headers=reg_headers, timeout=5)
            if reg_r.status_code == 201:
                reg_data = reg_r.json()
                new_hub_id = reg_data.get("hub_id")
                relay_secret = reg_data.get("relay_secret")
                if new_hub_id and relay_secret:
                    from dotenv import set_key
                    from pathlib import Path
                    env_file = Path(__file__).parent.parent.parent.parent / ".env"
                    if not env_file.exists():
                        with open(env_file, "w", encoding="utf-8") as f:
                            pass
                    set_key(str(env_file), "CLOUD_SERVER_URL", vps_url)
                    set_key(str(env_file), "HUB_ID", new_hub_id)
                    set_key(str(env_file), "HUB_RELAY_SECRET", relay_secret)
                    os.environ["CLOUD_SERVER_URL"] = vps_url
                    os.environ["HUB_ID"] = new_hub_id
                    os.environ["HUB_RELAY_SECRET"] = relay_secret
                    from hub.modules.communication.logic.cloud_bridge import cloud_bridge
                    cloud_bridge.stop()
                    cloud_bridge.start()
                    print(f"[AUTH] Hub no registrado, auto-vinculado a cuenta '{identifier}' (HUB_ID: {new_hub_id})")
        except Exception as e:
            print(f"[AUTH] Error al auto-vincular Hub en login: {e}")

@auth_view_bp.route("/login", methods=["GET", "POST"])
def login_view():
    if request.method == "POST":
        identifier = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()
        
        # 1. Intentar inicio de sesión local primero
        user = User.get_by_username_or_email(identifier)
        if user and user.verify_password(password):
            if not os.environ.get("HUB_ID"):
                try:
                    vps_url = _get_vps_url()
                    payload = {"email": user.email, "password": password, "is_hub": True, "username": user.username}
                    r = requests.post(f"{vps_url}/auth/login", json=payload, timeout=3)
                    if r.status_code == 200 and r.json().get("token"):
                        _auto_link_with_vps(vps_url, r.json().get("token"), user.username)
                    elif r.status_code == 401:
                        r_up = requests.post(f"{vps_url}/auth/signup", json=payload, timeout=3)
                        if r_up.status_code in (200, 201) and r_up.json().get("token"):
                            _auto_link_with_vps(vps_url, r_up.json().get("token"), user.username)
                except Exception as e:
                    print(f"[AUTH] Nota: No se pudo autovincular con el servidor exterior: {e}")

            session["logged_in"] = True
            session["username"] = user.username
            session["user_id"] = user.user_id
            next_url = request.args.get("next") or request.form.get("next")
            if next_url and next_url.startswith("/") and not next_url.startswith("/login") and not next_url.startswith("/logout"):
                return redirect(next_url)
            return redirect("/")
            
        # 2. Si no existe localmente, intentar con el VPS como respaldo.
        # El usuario pudo haberse registrado sólo en el VPS (desde la app).
        vps_url = _get_vps_url()
        try:
            # Intentar primero con email (si el identificador parece un email)
            # y si no, probar también como username a través del endpoint alternativo.
            payload = {"password": password}
            if "@" in identifier:
                payload["email"] = identifier.lower()
            else:
                # Puede ser username: enviamos ambos por si el servidor lo soporta
                payload["email"] = identifier.lower()  # el servidor busca por email
                payload["username"] = identifier

            payload["is_hub"] = True
            payload["hub_name"] = os.environ.get("HUB_NAME", "Central Colmena Hub")
            if os.environ.get("HUB_ID"):
                payload["hub_id"] = os.environ["HUB_ID"]

            r = requests.post(
                f"{vps_url}/auth/login",
                json=payload,
                timeout=5
            )

            if r.status_code == 200:
                data = r.json()
                vps_user = data.get("user", {})
                vps_username = vps_user.get("username", identifier.split('@')[0])
                vps_email    = vps_user.get("email", identifier)

                _auto_link_with_vps(vps_url, data.get("token"), vps_username)

                # Cachear usuario en la BD local del Hub para futuros logins sin internet
                local_user = User.get_by_username_or_email(vps_email)
                if not local_user:
                    local_user = User.create(
                        username=vps_username,
                        email=vps_email,
                        password=password
                    )

                session["logged_in"] = True
                session["username"] = local_user.username
                session["user_id"]  = local_user.user_id
                next_url = request.args.get("next") or request.form.get("next")
                if next_url and next_url.startswith("/") and not next_url.startswith("/login") and not next_url.startswith("/logout"):
                    return redirect(next_url)
                return redirect("/")

            elif r.status_code == 401:
                # VPS confirmó que las credenciales son incorrectas
                return render_template("views/auth/login.html", error="Credenciales inválidas. Verifica tu usuario o contraseña.")
            else:
                return render_template("views/auth/login.html", error=f"El servidor respondió con un error inesperado ({r.status_code}).")

        except requests.exceptions.ConnectionError:
            # Sin internet: si existe en local pero contraseña incorrecta, decirlo claramente
            if user:
                return render_template("views/auth/login.html", error="Contraseña incorrecta.")
            return render_template("views/auth/login.html",
                error="Sin conexión al servidor. Si es tu primera vez en este Hub, necesitas internet para verificar tu cuenta.")
        except requests.exceptions.Timeout:
            if user:
                return render_template("views/auth/login.html", error="Contraseña incorrecta.")
            return render_template("views/auth/login.html",
                error="El servidor tardó demasiado en responder. Inténtalo de nuevo.")
        except requests.exceptions.RequestException as e:
            return render_template("views/auth/login.html",
                error="Error de conexión con el servidor central." )
            
    msg = "Sesión cerrada correctamente." if request.args.get("logout") == "1" else None
    return render_template("views/auth/login.html", msg=msg)

@auth_view_bp.route("/register", methods=["GET", "POST"])
def register_view():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        email = request.form.get("email", "").strip()
        password = request.form.get("password", "").strip()
        confirm_password = request.form.get("confirm_password", "").strip()
        
        if password != confirm_password:
            return render_template("views/auth/register.html", error="Las contraseñas no coinciden.")
            
        if len(password) < 6:
            return render_template("views/auth/register.html", error="La contraseña debe tener al menos 6 caracteres.")
            
        existing = User.get_by_username_or_email(email)
        if existing:
            return render_template("views/auth/register.html", error="Este correo ya está registrado en el Hub.")
            
        # 1. Crear usuario local
        user = User.create(username=username, email=email, password=password)
        
        # 2. Intentar registrar en el VPS (síncrono pero con poco timeout)
        # Si falla, no importa, el usuario ya existe localmente
        vps_url = _get_vps_url()
        try:
            requests.post(f"{vps_url}/auth/signup", json={"username": username, "email": email, "password": password}, timeout=3)
        except requests.exceptions.RequestException:
            pass # Ignoramos errores de red, trabajaremos local
            
        # Iniciamos sesión automáticamente
        session["logged_in"] = True
        session["username"] = user.username
        session["user_id"] = user.user_id
        return redirect("/")
        
    return render_template("views/auth/register.html")

@auth_view_bp.route("/profile")
def profile_view():
    if not session.get("logged_in") and not session.get("user_id"):
        return redirect("/login")
        
    user = None
    user_id = session.get("user_id")
    if user_id:
        user = User.get_by_id(user_id)
    if not user:
        users = User.all()
        if users:
            user = users[0]
        else:
            return redirect("/login")
            
    from hub.modules.devices.models.device import Device
    from hub.modules.auth.models.room import Room
    from hub.modules.automation.models.skill import Skill
    
    devices_count = len(Device.all())
    rooms_count = len(Room.all())
    skills_count = len(Skill.all())
    
    hub_id = os.environ.get("HUB_ID", "No asignado (Modo Local)")
    cloud_url = os.environ.get("CLOUD_SERVER_URL", "http://157.173.102.129:8000/api")
    
    import socket
    local_ip = "127.0.0.1"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        pass
        
    from hub.modules.communication.logic.cloud_bridge import cloud_bridge
    cloud_stats = getattr(cloud_bridge, "stats", {
        "polls_sent": 0, "syncs_sent": 0, "commands_executed": 0,
        "last_sync_time": "No disponible", "last_poll_time": "No disponible", "status": "Inactivo"
    })

    return render_template(
        "views/auth/profile.html",
        user=user,
        hub_id=hub_id,
        cloud_url=cloud_url,
        local_ip=local_ip,
        devices_count=devices_count,
        rooms_count=rooms_count,
        skills_count=skills_count,
        cloud_stats=cloud_stats
    )

@auth_view_bp.route("/logout")
def logout_view():
    session.clear()
    return redirect("/login?logout=1")
