#!/usr/bin/env bash
# ==============================================================================
# server/service.sh
# Script de gestión para el Servidor IoT Bridge en Linux (Gunicorn + venv + systemd)
# ==============================================================================

SERVICE_NAME="iot-bridge"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${APP_DIR}/venv"
USER_NAME="$(whoami)"

# Colores para salida en terminal
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}⚠️  Este comando requiere permisos de superusuario (root).${NC}"
        echo -e "${YELLOW}   Por favor, ejecuta con: ${CYAN}sudo ./service.sh <comando>${NC}\n"
    fi
}

function show_menu() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${GREEN}  🍒 Gestión del Servidor IoT Bridge (venv + Gunicorn + systemd)  ${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "Servicio systemd: ${CYAN}${SERVICE_NAME}.service${NC}"
    echo -e "Directorio App:   ${CYAN}${APP_DIR}${NC}"
    echo -e "Entorno venv:     ${CYAN}${VENV_DIR}${NC}\n"
    echo -e "Opciones disponibles:"
    echo -e "  ${GREEN}1) setup / venv${NC}         -> Crear entorno virtual e instalar dependencias"
    echo -e "  ${GREEN}2) deps / install-deps${NC}  -> Solo instalar/actualizar dependencias en venv"
    echo -e "  ${GREEN}3) install / create${NC}     -> Crear y arrancar servicio systemd usando el venv"
    echo -e "  ${RED}4) stop${NC}                 -> Detener el servicio en segundo plano"
    echo -e "  ${GREEN}5) start${NC}                -> Iniciar el servicio"
    echo -e "  ${YELLOW}6) restart${NC}              -> Reiniciar el servicio"
    echo -e "  ${RED}7) remove / delete${NC}      -> Desinstalar y borrar el servicio systemd"
    echo -e "  ${CYAN}8) status${NC}               -> Ver el estado actual del servicio"
    echo -e "  ${CYAN}9) logs${NC}                 -> Ver los últimos 50 registros (logs)"
    echo -e "  ${CYAN}10) tail / monitor${NC}      -> Ver logs en tiempo real (-f)"
    echo -e "  ${BLUE}11) watch${NC}               -> Monitoreo continuo del estado"
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "Uso rápido: ${CYAN}./service.sh [setup|deps]${NC} ó ${CYAN}sudo ./service.sh [install|status|tail|...]${NC}\n"
}

function setup_venv() {
    echo -e "${BLUE}🐍 Creando entorno virtual en ${VENV_DIR}...${NC}"
    PYTHON_CMD=$(which python3 || which python)
    if [ -z "$PYTHON_CMD" ]; then
        echo -e "${RED}❌ No se encontró python3 en el sistema. Instálalo primero.${NC}"
        exit 1
    fi

    if [ ! -d "${VENV_DIR}" ]; then
        "$PYTHON_CMD" -m venv "${VENV_DIR}"
        echo -e "${GREEN}✔️ Entorno virtual creado exitosamente.${NC}"
    else
        echo -e "${YELLOW}ℹ️  El entorno virtual ya existía en ${VENV_DIR}.${NC}"
    fi

    install_deps
}

function install_deps() {
    echo -e "${BLUE}📦 Instalando / actualizando dependencias en el entorno virtual...${NC}"
    if [ ! -f "${VENV_DIR}/bin/pip" ]; then
        echo -e "${YELLOW}⚠️  No se detectó pip en el venv. Creando entorno virtual primero...${NC}"
        setup_venv
        return
    fi

    "${VENV_DIR}/bin/pip" install --upgrade pip
    "${VENV_DIR}/bin/pip" install -r "${APP_DIR}/requirements.txt"
    echo -e "${GREEN}✔️ Dependencias (incluyendo Gunicorn y Flask) instaladas en ${VENV_DIR}.${NC}"
}

function install_service() {
    check_root
    echo -e "${BLUE}⚙️  Configurando servicio ${SERVICE_NAME}.service para producción...${NC}"

    # Asegurar que el entorno virtual y Gunicorn existan antes de crear el servicio
    if [ ! -f "${VENV_DIR}/bin/gunicorn" ]; then
        echo -e "${YELLOW}⚠️  No se encontró Gunicorn en el venv. Ejecutando instalación de dependencias...${NC}"
        setup_venv
    fi

    GUNICORN_BIN="${VENV_DIR}/bin/gunicorn"
    if [ ! -f "${GUNICORN_BIN}" ]; then
        echo -e "${RED}❌ Error: No se pudo localizar ${GUNICORN_BIN}.${NC}"
        exit 1
    fi

    echo -e "🔍 Binario Gunicorn verificado en: ${CYAN}${GUNICORN_BIN}${NC}"

    cat <<EOF | sudo tee ${SERVICE_FILE} > /dev/null
[Unit]
Description=IoT Bridge Server (Isolated Gunicorn Production Service)
After=network.target

[Service]
User=${USER_NAME}
Group=${USER_NAME}
WorkingDirectory=${APP_DIR}
Environment="PATH=${VENV_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="VIRTUAL_ENV=${VENV_DIR}"
Environment="SERVER_MODE=auto"
Environment="SERVER_PORT=8000"
ExecStart=${GUNICORN_BIN} --workers 4 --threads 2 --bind 0.0.0.0:8000 --timeout 60 --access-logfile - --error-logfile - main:app
Restart=always
RestartSec=3
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✔️ Archivo systemd creado en ${SERVICE_FILE}${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}.service
    sudo systemctl start ${SERVICE_NAME}.service
    echo -e "${GREEN}🚀 Servicio iniciado corriendo 100% aislado en su entorno virtual.${NC}\n"
    sudo systemctl status ${SERVICE_NAME}.service --no-pager -n 12
}

function stop_service() {
    check_root
    echo -e "${YELLOW}🛑 Deteniendo ${SERVICE_NAME}.service...${NC}"
    sudo systemctl stop ${SERVICE_NAME}.service
    echo -e "${GREEN}✔️ Servicio detenido.${NC}"
}

function start_service() {
    check_root
    echo -e "${GREEN}▶️  Iniciando ${SERVICE_NAME}.service...${NC}"
    sudo systemctl start ${SERVICE_NAME}.service
    echo -e "${GREEN}✔️ Servicio en ejecución.${NC}"
}

function restart_service() {
    check_root
    echo -e "${YELLOW}🔄 Reiniciando ${SERVICE_NAME}.service...${NC}"
    sudo systemctl restart ${SERVICE_NAME}.service
    echo -e "${GREEN}✔️ Reinicio completado.${NC}"
}

function remove_service() {
    check_root
    echo -e "${RED}🗑️  Desinstalando y eliminando ${SERVICE_NAME}.service...${NC}"
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        sudo systemctl stop ${SERVICE_NAME}.service 2>/dev/null
        sudo systemctl disable ${SERVICE_NAME}.service 2>/dev/null
    fi
    if [ -f "${SERVICE_FILE}" ]; then
        sudo rm -f ${SERVICE_FILE}
    fi
    sudo systemctl daemon-reload
    sudo systemctl reset-failed 2>/dev/null
    echo -e "${GREEN}✔️ Servicio eliminado exitosamente.${NC}"
}

function status_service() {
    echo -e "${CYAN}📊 Estado del servicio ${SERVICE_NAME}.service:${NC}"
    sudo systemctl status ${SERVICE_NAME}.service --no-pager -n 25
}

function logs_service() {
    echo -e "${CYAN}📜 Últimos registros de ${SERVICE_NAME}.service:${NC}"
    sudo journalctl -u ${SERVICE_NAME}.service -n 50 --no-pager
}

function tail_service() {
    echo -e "${GREEN}📡 Monitoreando logs en tiempo real (Ctrl+C para salir):${NC}"
    sudo journalctl -u ${SERVICE_NAME}.service -f
}

function watch_service() {
    echo -e "${GREEN}🔄 Estado en tiempo real del servicio (Ctrl+C para salir):${NC}"
    watch -n 1 "systemctl status ${SERVICE_NAME}.service --no-pager -n 15"
}

# Procesar argumentos de consola
CASE_ARG="${1:-menu}"

case "${CASE_ARG}" in
    setup|venv|1)
        setup_venv
        ;;
    deps|install-deps|2)
        install_deps
        ;;
    install|create|3)
        install_service
        ;;
    stop|4)
        stop_service
        ;;
    start|5)
        start_service
        ;;
    restart|6)
        restart_service
        ;;
    remove|delete|uninstall|7)
        remove_service
        ;;
    status|8)
        status_service
        ;;
    logs|9)
        logs_service
        ;;
    tail|monitor|follow|10)
        tail_service
        ;;
    watch|11)
        watch_service
        ;;
    menu|help|-h|--help)
        show_menu
        echo -n "Selecciona una opción [1-11]: "
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
            *) echo -e "${RED}Opción no válida.${NC}" ;;
        esac
        ;;
    *)
        echo -e "${RED}Comando desconocido: $1${NC}"
        show_menu
        exit 1
        ;;
esac
