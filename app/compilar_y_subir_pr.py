#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
Script Integral en Python para Compilación Flutter y Subida de Pull Request (PR)
Permite inyectar la IP o Dominio del Servidor/Central al momento de compilar.
==============================================================================
"""

import os
import sys
import time
import argparse
import subprocess
from pathlib import Path

# Códigos de color ANSI multiplataforma (habilitados en Windows 10+ si es posible)
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

def print_header():
    print(f"{Colors.MAGENTA}================================================================={Colors.END}")
    print(f"{Colors.MAGENTA}   FLUTTER BUILD & GITHUB PR UPLOADER (PYTHON) - HOGAR COLMENA   {Colors.END}")
    print(f"{Colors.MAGENTA}================================================================={Colors.END}\n")

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
    """Ejecuta un comando en consola mostrando la salida en tiempo real."""
    cmd_formatted, use_shell = format_cmd_for_platform(cmd)
    info(f"Ejecutando: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    res = subprocess.run(cmd_formatted, cwd=cwd, shell=use_shell)
    if check and res.returncode != 0:
        err(f"El comando falló con código de salida: {res.returncode}")
        sys.exit(res.returncode)
    return res.returncode

def find_flutter_project_dir() -> Path:
    """Detecta la carpeta raíz del proyecto Flutter ('pubspec.yaml')."""
    current = Path.cwd().resolve()
    if (current / "pubspec.yaml").is_file():
        return current
    elif (current / "app" / "pubspec.yaml").is_file():
        return current / "app"
    else:
        err(f"No se encontró 'pubspec.yaml' ni en '{current}' ni en '{current / 'app'}'.")
        sys.exit(1)

def get_git_branch(cwd: Path) -> str:
    try:
        cmd_f, use_s = format_cmd_for_platform(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        res = subprocess.run(cmd_f, cwd=cwd, capture_output=True, text=True, check=True, shell=use_s)
        return res.stdout.strip() or "main"
    except Exception:
        return "main"

def check_git_status_clean(cwd: Path) -> bool:
    try:
        cmd_f, use_s = format_cmd_for_platform(["git", "status", "--porcelain"])
        res = subprocess.run(cmd_f, cwd=cwd, capture_output=True, text=True, shell=use_s)
        return len(res.stdout.strip()) == 0
    except Exception:
        return True

def main():
    print_header()

    parser = argparse.ArgumentParser(description="Compilador Flutter + Inyector IP + Subida PR")
    parser.add_argument("ip", nargs="?", help="IP y puerto del Servidor Colmena (ej: 192.168.1.100:5000)")
    parser.add_argument("--target", "-t", default="apk", choices=["apk", "appbundle", "web", "windows"], help="Tipo de compilación Flutter")
    parser.add_argument("--pr", "-p", action="store_true", help="Subir a Git y crear Pull Request automáticamente tras compilar")
    parser.add_argument("--branch", "-b", help="Rama de Git a la cual subir (por defecto: rama actual)")
    parser.add_argument("--message", "-m", help="Mensaje de commit")

    args = parser.parse_args()

    # 1. Obtener IP del servidor (interactivo si no vino por parámetro)
    server_ip = args.ip
    if not server_ip:
        print(f"{Colors.BOLD}Ingresa la dirección IP y puerto del servidor Colmena al que debe conectarse la App:{Colors.END}")
        server_ip = input("Ejemplo (192.168.1.100:5000) [Enter para usar 192.168.1.100:5000]: ").strip()
        if not server_ip:
            server_ip = "157.173.102.129:5000"

    info(f"La App será compilada con el servidor en: -> {Colors.BOLD}{server_ip}{Colors.END} <-")
    print()

    # 2. Localizar directorio de la App Flutter
    app_dir = find_flutter_project_dir()
    info(f"Directorio de la App Flutter detectado: {app_dir}\n")

    # 3. Limpieza y preparación de dependencias
    info("Limpiando compilaciones anteriores (flutter clean)...")
    run_cmd(["flutter", "clean"], cwd=app_dir)

    info("Obteniendo paquetes y dependencias (flutter pub get)...")
    run_cmd(["flutter", "pub", "get"], cwd=app_dir)

    # 4. Compilar Flutter con --dart-define
    info(f"Iniciando compilación de {args.target.upper()} para Release...")
    start_time = time.time()
    
    build_cmd = [
        "flutter", "build", args.target,
        "--release",
        f"--dart-define=HUB_HOST={server_ip}"
    ]
    run_cmd(build_cmd, cwd=app_dir)
    
    elapsed = round(time.time() - start_time, 1)
    success(f"¡Compilación completada exitosamente en {elapsed} segundos!\n")

    # Mostrar ruta del archivo generado si aplica
    if args.target == "apk":
        out_apk = app_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        if out_apk.is_file():
            success(f"Archivo APK generado en: {out_apk}")
    elif args.target == "appbundle":
        out_aab = app_dir / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
        if out_aab.is_file():
            success(f"Archivo AAB generado en: {out_aab}")
    print()

    # 5. Gestión Git y Pull Request
    create_pr = args.pr
    if not create_pr:
        print(f"{Colors.YELLOW}¿Deseas subir los cambios a Git y crear/actualizar un Pull Request (PR) ahora? (s/n){Colors.END}")
        resp = input("> ").strip().lower()
        if resp.startswith('s'):
            create_pr = True

    if create_pr:
        print(f"\n{Colors.MAGENTA}-----------------------------------------------------------------{Colors.END}")
        info("Iniciando proceso de Git y creación de Pull Request (PR)...")

        branch = args.branch or get_git_branch(app_dir)
        info(f"Rama de Git de trabajo: {branch}")

        if not check_git_status_clean(app_dir):
            info("Preparando archivos modificados en Git...")
            run_cmd(["git", "add", "."], cwd=app_dir)
            commit_msg = args.message or f"chore(build): release app configurada con servidor {server_ip}"
            run_cmd(["git", "commit", "-m", commit_msg], cwd=app_dir)
            success(f"Commit realizado: '{commit_msg}'")
        else:
            info("No hay cambios pendientes en el código por commitear.")

        info(f"Subiendo rama al repositorio remoto (git push origin {branch})...")
        cmd_f, use_s = format_cmd_for_platform(["git", "push", "-u", "origin", branch])
        push_res = subprocess.run(cmd_f, cwd=app_dir, shell=use_s)
        if push_res.returncode != 0:
            warn(f"No se pudo subir automáticamente con 'git push -u origin {branch}'. Revisa permisos o conexión.")
        else:
            success(f"Rama {branch} subida exitosamente a origin.")

        # Verificar si GitHub CLI (gh) está instalado
        cmd_f, use_s = format_cmd_for_platform(["gh", "--version"])
        gh_check = subprocess.run(cmd_f, cwd=app_dir, capture_output=True, shell=use_s)
        if gh_check.returncode == 0:
            info("GitHub CLI (gh) detectado. Creando Pull Request automáticamente...")
            pr_title = f"🚀 Release / Build App (Servidor: {server_ip})"
            pr_body = (
                f"### 📱 Compilación de Aplicación Hogar Colmena\n\n"
                f"**Parámetros del Build:**\n"
                f"- **Servidor Central Configurado:** `{server_ip}`\n"
                f"- **Tipo de Compilación:** `{args.target}`\n"
                f"- **Rama:** `{branch}`\n\n"
                f"Este PR incluye las últimas mejoras UX y la configuración nativa de conexión al servidor."
            )
            cmd_f, use_s = format_cmd_for_platform(["gh", "pr", "create", "--title", pr_title, "--body", pr_body])
            pr_res = subprocess.run(cmd_f, cwd=app_dir, shell=use_s)
            if pr_res.returncode == 0:
                success("¡Pull Request (PR) creado y publicado en GitHub con éxito!")
            else:
                warn("El PR ya existía para esta rama o hubo una alerta de GitHub CLI.")
                cmd_f, use_s = format_cmd_for_platform(["gh", "pr", "view", "--web"])
                subprocess.run(cmd_f, cwd=app_dir, shell=use_s)
        else:
            warn("GitHub CLI ('gh') no está instalado en tu sistema.")
            info(f"Para crear tu PR, abre la interfaz web de GitHub/GitLab y selecciona la rama '{branch}'.")

    print(f"\n{Colors.GREEN}=======================================