#!/bin/sh
# ==============================================================================
# server/service.sh
# Script POSIX compatible (sh / bash / dash) de gestión IoT Bridge en Linux
# ==============================================================================

SERVICE_NAME="iot-bridge"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${APP_DIR}/venv"
USER_NAME="$(id -un 2>/dev/null || whoami)"

# Colores para salida usando printf (100% compatible con POSIX sh/dash)
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

print_msg() {
    printf "%b\n" "$1"
}

check_root() {
    id_user=$(id -u 2>/dev/null || echo 1)
    if [ "$id_user" -ne 0 ]; then
        print_msg "${YELLOW}⚠️  Este comando requiere permisos de superusuario (root).${NC}"
        print_msg "${YELLOW}   Por favor, ejecuta con: ${CYAN}sudo sh service.sh <comando>${NC}\n"
    fi
}

show_menu() {
    print_msg "${BLUE}======================================================================${NC}"
    print_msg "${GREEN}  🍒 Gestión del Servidor IoT Bridge (venv + Gunicorn + systemd)  ${NC}"
    print_msg "${BLUE}======================================================================${NC}"
    print_msg "Servicio systemd: ${CYAN}${SERVICE_NAME}.service${NC}"
    print_msg "Directorio App:   ${CYAN}${APP_DIR}${NC}"
    print_msg "Entorno venv:     ${CYAN}${VENV_DIR}${NC}\n"
    print_msg "Opciones disponibles:"
    print_msg "  ${GREEN}1) setup / venv${NC}         -> Crear entorno virtual e instalar dependencias"
    print_msg "  ${GREEN}2) deps / install-deps${NC}  -> Solo instalar/actualizar dependencias en venv"
    print_msg "  ${GREEN}3) install / create${NC}     -> Crear y arrancar servicio systemd usando el venv"
    print_msg "  ${RED}4) stop${NC}                 -> Detener el servicio en segundo plano"
    print_msg "  ${GREEN}5) start${NC}                -> Iniciar el servicio"
    print_msg "  ${YELLOW}6) restart${NC}              -> Reiniciar el servicio"
    print_msg "  ${RED}7) remove / delete${NC}      -> Desinstalar y borrar el servicio systemd"
    print_msg "  ${CYAN}8) status${NC}               -> Ver el estado actual del servicio"
    print_msg "  ${CYAN}9) logs${NC}                 -> Ver los últimos 50 registros (logs)"
    print_msg "  ${CYAN}10) tail / monitor${NC}      -> Ver logs en tiempo real (-f)"
    print_msg "  ${BLUE}11) watch${NC}               -> Monitoreo continuo del estado"
    print_msg "${BLUE}======================================================================${NC}"
    print_msg "Uso rápido: ${CYAN}sh service.sh [setup|deps]${NC} ó ${CYAN}sudo sh service.sh [install|status|tail|...]${NC}\n"
}

setup_venv() {
    print_msg "${BLUE}🐍 Creando entorno virtual en ${VENV_DIR}...${NC}"
    PYTHON_CMD=""
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    fi

    if [ -z "$PYTHON_CMD" ]; then
        print_msg "${RED}❌ No se encontró python3 en el sistema. Instálalo primero (ej: apt install python3 python3-venv).${NC}"
        exit 1
    fi

    if [ ! -d "${VENV_DIR}" ]; then
        "$PYTHON_CMD" -m venv "${VENV_DIR}"
        print_msg "${GREEN}✔️ Entorno virtual creado exitosamente.${NC}"
    else
        print_msg "${YELLOW}ℹ️  El entorno virtual ya existía en ${VENV_DIR}.${NC}"
    fi

    install_deps
}

install_deps() {
    print_msg "${BLUE}📦 Instalando / actualizando dependencias en el entorno virtual...${NC}"
    if [ ! -f "${VENV_DIR}/bin/pip" ]; then
        print_msg "${YELLOW}⚠️  No se detectó pip en el venv. Creando entorno virtual primero...${NC}"
        setup_venv
        return
    fi

    "${VENV_DIR}/bin/pip" install --upgrade pip
    "${VENV_DIR}/bin/pip" install -r "${APP_DIR}/requirements.txt"
    print_msg "${GREEN}✔️ Dependencias (incluyendo Gunicorn y Flask) instaladas en ${VENV_DIR}.${NC}"
}

install_service() {
    check_root
    print_msg "${BLUE}⚙️  Configurando servicio ${SERVICE_NAME}.service para producción...${NC}"

    if [ ! -f "${VENV_DIR}/bin/gunicorn" ]; then
        print_msg "${YELLOW}⚠️  No se encontró Gunicorn en el venv. Ejecutando instalación de dependencias...${NC}"
        setup_venv
    fi

    GUNICORN_BIN="${VENV_DIR}/bin/gunicorn"
    if [ ! -f "${GUNICORN_BIN}" ]; then
        print_msg "${RED}❌ Error: No se pudo localizar ${GUNICORN_BIN}.${NC}"
        exit 1
    fi

    print_msg "🔍 Binario Gunicorn verificado en: ${CYAN}${GUNICORN_BIN}${NC}"

    cat <<EOF | tee ${SERVICE_FILE} > /dev/null
[Unit]
Description=IoT Bridge Server (Isolated Gunicorn Production Service)
After=network.target

[Service]
User=${USER_NAME}
Group=${USER_NAME}
WorkingDirectory=${APP_DIR}
Environment="PATH=${VENV_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="VIRTUAL_ENV=${VENV_DIR}"
Environment="PYTHONPATH=${APP_DIR}"
Environment="SERVER_MODE=auto"
Environment="SERVER_PORT=8000"
ExecStart=${GUNICORN_BIN} --workers 4 --threads 2 --bind 0.0.0.0:8000 --timeout 60 --access-logfile - --error-logfile - main:app
Restart=always
RestartSec=3
KillSignal=SIGQUIT
Type=simple

[Install]
WantedBy=multi-user.target
EOF

    print_msg "${GREEN}✔️ Archivo systemd creado en ${SERVICE_FILE}${NC}"
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}.service
    
    if systemctl start ${SERVICE_NAME}.service; then
        print_msg "${GREEN}🚀 Servicio iniciado corriendo 100% aislado en su entorno virtual.${NC}\n"
    else
        print_msg "${RED}❌ Error al arrancar el servicio. Mostrando logs exactos del fallo:${NC}\n"
        journalctl -u ${SERVICE_NAME}.service -n 30 --no-pager
    fi
    systemctl status ${SERVICE_NAME}.service --no-pager -n 12
}

stop_service() {
    check_root
    print_msg "${YELLOW}🛑 Deteniendo ${SERVICE_NAME}.service...${NC}"
    systemctl stop ${SERVICE_NAME}.service
    print_msg "${GREEN}✔️ Servicio detenido.${NC}"
}

start_service() {
    check_root
    print_msg "${GREEN}▶️  Iniciando ${SERVICE_NAME}.service...${NC}"
    systemctl start ${SERVICE_NAME}.service
    print_msg "${GREEN}✔️ Servicio en ejecución.${NC}"
}

restart_service() {
    check_root
    print_msg "${YELLOW}🔄 Reiniciando ${SERVICE_NAME}.service...${NC}"
    systemctl restart ${SERVICE_NAME}.service
    print_msg "${GREEN}✔️ Reinicio completado.${NC}"
}

remove_service() {
    check_root
    print_msg "${RED}🗑️  Desinstalando y eliminando ${SERVICE_NAME}.service...${NC}"
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        systemctl stop ${SERVICE_NAME}.service 2>/dev/null
        systemctl disable ${SERVICE_NAME}.service 2>/dev/null
    fi
    if [ -f "${SERVICE_FILE}" ]; then
        rm -f ${SERVICE_FILE}
    fi
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null
    print_msg "${GREEN}✔️ Servicio eliminado exitosamente.${NC}"
}

status_service() {
    print_msg "${CYAN}📊 Estado del servicio ${SERVICE_NAME}.service:${NC}"
    systemctl status ${SERVICE_NAME}.service --no-pager -n 25
}

logs_service() {
    print_msg "${CYAN}📜 Últimos registros de ${SERVICE_NAME}.service:${NC}"
    journalctl -u ${SERVICE_NAME}.service -n 50 --no-pager
}

tail_service() {
    print_msg "${GREEN}📡 Monitoreando logs en tiempo real (Ctrl+C para salir):${NC}"
    journalctl -u ${SERVICE_NAME}.service -f
}

watch_service() {
    print_msg "${GREEN}🔄 Estado en tiempo real del servicio (Ctrl+C para salir):${NC}"
    watch -n 1 "systemctl status ${SERVICE_NAME}.service --no-pager -n 15"
}

CASE_ARG="${1:-menu}"

case "${CASE_ARG}" in
    setup|venv|1) setup_venv ;;
    deps|install-deps|2) install_deps ;;
    install|create|3) install_service ;;
    stop|4) stop_service ;;
    start|5) start_service ;;
    restart|6) restart_service ;;
    remove|delete|uninstall|7) remove_service ;;
    status|8) status_service ;;
    logs|9) logs_service ;;
    tail|monitor|follow|10) tail_service ;;
    watch|11) watch_service ;;
    menu|help|-h|--help)
        show_menu
        printf "Selecciona una opción [1-11]: "
        read -r opt
        case "${opt}" in
            1) setup_venv ;;
            2) install_deps ;;
            3) install_service ;;
            4) stop_service ;;
            5) start_service ;;
            6) restart_service ;;
            7) remove_service ;;
            8) status_service ;;
            9) logs_service ;;
            10) tail_service ;;
            11) watch_service ;;
            *) print_msg "${RED}Opción no válida.${NC}" ;;
        esac
        ;;
    *)
        print_msg "${RED}Comando desconocido: $1${NC}"
        show_menu
        exit 1
        ;;
esac
