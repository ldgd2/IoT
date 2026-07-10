#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
GESTOR DE RELEASES Y COMPILACIÓN FLUTTER - HOGAR COLMENA
Permite compilar, instalar por ADB (opcional), gestionar versiones y subir PR.
==============================================================================
"""

import os
import sys
import time
import subprocess
from pathlib import Path

# ==============================================================================
# 0. VERIFICACIÓN E INSTALACIÓN DE DEPENDENCIAS PYTHON
# ==============================================================================
try:
    import yaml
    import requests
    from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor
    from tqdm import tqdm
except ImportError:
    print("❌ Faltan dependencias Python. Instalando pyyaml, requests, requests-toolbelt y tqdm...")
    subprocess.run([sys.executable, "-m", "pip", "install", "pyyaml", "requests", "requests-toolbelt", "tqdm"], check=False)
    print("✅ Dependencias instaladas. Cargando módulos...")
    import yaml
    import requests
    from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor
    from tqdm import tqdm

# Códigos de color ANSI multiplataforma
if os.name == 'nt':
    os.system('color')

class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'

def info(msg: str):
    print(f"{Colors.CYAN}[INFO] {msg}{Colors.END}")

def success(msg: str):
    print(f"{Colors.GREEN}[ÉXITO] {msg}{Colors.END}")

def warn(msg: str):
    print(f"{Colors.YELLOW}[ALERTA] {msg}{Colors.END}")

def err(msg: str):
    print(f"{Colors.RED}[ERROR] {msg}{Colors.END}")

# ==============================================================================
# 1. CONFIGURACIÓN GLOBALES Y DIRECTORIOS
# ==============================================================================
BASE_DIR = Path(__file__).resolve().parent
if not (BASE_DIR / "pubspec.yaml").is_file():
    if (BASE_DIR / "app" / "pubspec.yaml").is_file():
        BASE_DIR = BASE_DIR / "app"

DEFAULT_SERVER_IP = "157.173.102.129:8000"
CURRENT_SERVER_IP = DEFAULT_SERVER_IP

def ensure_java_home():
    """Detecta y configura JAVA_HOME en Windows si no está definido o es inválido para Gradle."""
    if os.name == 'nt':
        current_jh = os.environ.get("JAVA_HOME")
        if current_jh and Path(current_jh).is_dir() and (Path(current_jh) / "bin" / "java.exe").is_file():
            return
        candidates = [
            Path("C:/Program Files/Java"),
            Path("C:/Program Files/Android/Android Studio/jbr"),
            Path("C:/Program Files/Android/Android Studio/jre")
        ]
        for base in candidates:
            if base.is_dir():
                if (base / "bin" / "java.exe").is_file():
                    os.environ["JAVA_HOME"] = str(base)
                    info(f"JAVA_HOME detectado y configurado: {base}")
                    return
                for sub in sorted(base.glob("jdk*"), reverse=True):
                    if (sub / "bin" / "java.exe").is_file():
                        os.environ["JAVA_HOME"] = str(sub)
                        info(f"JAVA_HOME detectado y configurado: {sub}")
                        return

def get_version_from_pubspec(app_path: Path):
    pubspec_path = app_path / "pubspec.yaml"
    if not pubspec_path.exists():
        err(f"No se encontró {pubspec_path}")
        return None
    
    with open(pubspec_path, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
        version_string = data.get('version', '1.0.0+1')
        return version_string.split('+')[0]

def format_cmd_for_platform(cmd):
    if os.name == 'nt':
        if isinstance(cmd, list):
            return ' '.join(cmd), True
        return cmd, True
    else:
        if isinstance(cmd, str):
            return cmd.split(), False
        return cmd, False

def run_cmd(cmd, cwd=None, check=True):
    cmd_formatted, use_shell = format_cmd_for_platform(cmd)
    info(f"Ejecutando: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    res = subprocess.run(cmd_formatted, cwd=cwd, shell=use_shell)
    if res.returncode != 0:
        err(f"El comando falló con código de salida: {res.returncode}")
        return False
    return True

# ==============================================================================
# 2. LÓGICA DE COMPILACIÓN, ADB Y PR
# ==============================================================================
def compile_flutter(target="apk", server_ip=CURRENT_SERVER_IP) -> bool:
    print(f"\n{Colors.MAGENTA}{'='*60}{Colors.END}")
    print(f"{Colors.MAGENTA} 🚀 INICIANDO COMPILACIÓN FLUTTER ({target.upper()}) - HOGAR COLMENA{Colors.END}")
    print(f"{Colors.MAGENTA}{'='*60}{Colors.END}")

    ensure_java_home()

    version = get_version_from_pubspec(BASE_DIR)
    if not version:
        return False
    
    print(f"📦 Versión en pubspec.yaml: {Colors.BOLD}{version}{Colors.END}")
    print(f"🔧 Servidor Central inyectado: {Colors.BOLD}{server_ip}{Colors.END}")
    print("⏳ Compilando (Release)... Esto puede tardar unos minutos.\n")

    start_time = time.time()
    build_cmd = [
        "flutter", "build", target,
        "--release",
        f"--dart-define=HUB_HOST={server_ip}"
    ]
    
    if not run_cmd(build_cmd, cwd=BASE_DIR, check=False):
        err(f"La compilación de {target.upper()} falló. Abortando.")
        return False

    elapsed = round(time.time() - start_time, 1)
    success(f"¡Compilación terminada con éxito en {elapsed} segundos!\n")

    if target == "apk":
        apk_path = BASE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        if apk_path.is_file():
            success(f"APK disponible en: {apk_path}")
            return True
        else:
            err("No se encontró el APK en la ruta esperada.")
            return False
    elif target == "appbundle":
        aab_path = BASE_DIR / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
        if aab_path.is_file():
            success(f"AAB disponible en: {aab_path}")
            return True
    return True

def install_via_adb():
    apk_path = BASE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk_path.is_file():
        err("No hay un APK compilado previamente para instalar. Compila primero.")
        return False

    print(f"\n📱 Instalando APK en tu dispositivo conectado vía ADB...")
    cmd_f, use_s = format_cmd_for_platform(["adb", "install", "-r", str(apk_path)])
    res = subprocess.run(cmd_f, cwd=BASE_DIR, shell=use_s)
    if res.returncode == 0:
        success("¡Aplicación instalada en el dispositivo móvil correctamente!")
        return True
    else:
        warn("Error al instalar con ADB (¿El celular tiene depuración USB activa o no está conectado?).")
        return False

def push_git_and_pr(server_ip=CURRENT_SERVER_IP):
    print(f"\n{Colors.CYAN}{'='*60}{Colors.END}")
    info("Iniciando subida a Git y creación de Pull Request (PR)...")

    # Detectar rama actual
    try:
        cmd_f, use_s = format_cmd_for_platform(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        res = subprocess.run(cmd_f, cwd=BASE_DIR, capture_output=True, text=True, check=True, shell=use_s)
        branch = res.stdout.strip() or "main"
    except Exception:
        branch = "main"

    info(f"Rama de Git de trabajo: {branch}")

    # Verificar estado
    cmd_f, use_s = format_cmd_for_platform(["git", "status", "--porcelain"])
    status_res = subprocess.run(cmd_f, cwd=BASE_DIR, capture_output=True, text=True, shell=use_s)
    
    if len(status_res.stdout.strip()) > 0:
        info("Preparando cambios pendientes en Git...")
        run_cmd(["git", "add", "."], cwd=BASE_DIR)
        version = get_version_from_pubspec(BASE_DIR) or "1.0.0"
        commit_msg = f"chore(release): build v{version} conectado a central {server_ip}"
        run_cmd(["git", "commit", "-m", commit_msg], cwd=BASE_DIR)
        success(f"Commit generado: '{commit_msg}'")
    else:
        info("No hay cambios pendientes en el código por commitear.")

    info(f"Subiendo rama al remoto (git push origin {branch})...")
    cmd_f, use_s = format_cmd_for_platform(["git", "push", "-u", "origin", branch])
    push_res = subprocess.run(cmd_f, cwd=BASE_DIR, shell=use_s)
    if push_res.returncode != 0:
        warn(f"No se pudo hacer push automático a origin/{branch}.")
    else:
        success(f"Rama {branch} subida exitosamente a origin.")

    # Verificar GitHub CLI (gh)
    cmd_f, use_s = format_cmd_for_platform(["gh", "--version"])
    gh_check = subprocess.run(cmd_f, cwd=BASE_DIR, capture_output=True, shell=use_s)
    if gh_check.returncode == 0:
        info("GitHub CLI (gh) detectado. Creando Pull Request automáticamente...")
        pr_title = f"🚀 Release / Build App v{get_version_from_pubspec(BASE_DIR) or '1.0'} (Servidor: {server_ip})"
        pr_body = (
            f"### 📱 Compilación y Release Hogar Colmena\n\n"
            f"**Configuración:**\n"
            f"- **Servidor Central Configurado:** `{server_ip}`\n"
            f"- **Rama:** `{branch}`\n\n"
            f"Incluye la inyección nativa de la Central en producción e instalación por ADB."
        )
        cmd_f, use_s = format_cmd_for_platform(["gh", "pr", "create", "--title", pr_title, "--body", pr_body])
        pr_res = subprocess.run(cmd_f, cwd=BASE_DIR, shell=use_s)
        if pr_res.returncode == 0:
            success("¡Pull Request creado y publicado en GitHub!")
        else:
            warn("El PR ya existía para esta rama o hubo un aviso de GitHub CLI.")
            cmd_f, use_s = format_cmd_for_platform(["gh", "pr", "view", "--web"])
            subprocess.run(cmd_f, cwd=BASE_DIR, shell=use_s)
    else:
        warn("GitHub CLI ('gh') no está instalado. Crea tu PR directamente en la web del repositorio.")

# ==============================================================================
# 3. MENÚ INTERACTIVO PRINCIPAL
# ==============================================================================
def main():
    global CURRENT_SERVER_IP
    while True:
        version = get_version_from_pubspec(BASE_DIR) or "?"
        print("\n" + Colors.MAGENTA + "="*60 + Colors.END)
        print(f"{Colors.BOLD}   GESTOR DE RELEASES FLUTTER - HOGAR COLMENA (v{version}){Colors.END}")
        print(f"   🌐 Servidor actual configurado: {Colors.CYAN}{CURRENT_SERVER_IP}{Colors.END}")
        print(Colors.MAGENTA + "="*60 + Colors.END)
        print("1. Compilar APK (Release)")
        print("2. Compilar APK e INSTALAR en móvil vía ADB")
        print("3. Compilar APK + Subir a Git & Crear Pull Request (PR)")
        print("4. Compilar APK, INSTALAR (ADB) + Subir PR completo")
        print("-" * 60)
        print("5. Compilar AppBundle (.aab) para Play Store")
        print("6. Cambiar dirección IP/Puerto de la Central Colmena")
        print("-" * 60)
        print("7. Salir")
        print(Colors.MAGENTA + "="*60 + Colors.END)
        
        try:
            opcion = input("Selecciona una opción (1-7): ").strip()
        except KeyboardInterrupt:
            print("\nSaliendo...")
            sys.exit(0)

        if opcion == '1':
            compile_flutter("apk", CURRENT_SERVER_IP)
        elif opcion == '2':
            if compile_flutter("apk", CURRENT_SERVER_IP):
                install_via_adb()
        elif opcion == '3':
            if compile_flutter("apk", CURRENT_SERVER_IP):
                push_git_and_pr(CURRENT_SERVER_IP)
        elif opcion == '4':
            if compile_flutter("apk", CURRENT_SERVER_IP):
                install_via_adb()
                push_git_and_pr(CURRENT_SERVER_IP)
        elif opcion == '5':
            compile_flutter("appbundle", CURRENT_SERVER_IP)
        elif opcion == '6':
            print(f"\n{Colors.BOLD}Ingresa la nueva IP:Puerto del Servidor Colmena:{Colors.END}")
            nueva_ip = input(f"Ejemplo (192.168.1.100:5000) [Enter para mantener {CURRENT_SERVER_IP}]: ").strip()
            if nueva_ip:
                CURRENT_SERVER_IP = nueva_ip
                success(f"Servidor actualizado a: {CURRENT_SERVER_IP}")
        elif opcion == '7':
            print("Saliendo del gestor de releases...")
            sys.exit(0)
        else:
            err("Opción inválida. Intenta nuevamente.")

if __name__ == "__main__":
    main()
