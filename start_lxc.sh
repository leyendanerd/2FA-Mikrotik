#!/bin/bash

# Script de inicio rápido para Mikrotik 2FA en LXC
# Ejecutar con: bash start_lxc.sh

set -e

echo "=========================================="
echo "Iniciador de Mikrotik 2FA en LXC"
echo "=========================================="

# Obtener directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Función para mostrar estado
show_status() {
    echo "Estado de los servicios:"
    echo "-----------------------"
    
    if systemctl is-active --quiet freeradius; then
        echo "✓ FreeRADIUS: ACTIVO"
    else
        echo "✗ FreeRADIUS: INACTIVO"
    fi
    
    if systemctl is-active --quiet mikrotik-2fa; then
        echo "✓ Mikrotik 2FA: ACTIVO"
    else
        echo "✗ Mikrotik 2FA: INACTIVO"
    fi
    
    echo ""
}

# Función para iniciar servicios
start_services() {
    echo "Iniciando servicios..."
    
    # Iniciar FreeRADIUS
    if ! systemctl is-active --quiet freeradius; then
        echo "Iniciando FreeRADIUS..."
        sudo systemctl start freeradius
    else
        echo "✓ FreeRADIUS ya está ejecutándose"
    fi
    
    # Iniciar Mikrotik 2FA
    if ! systemctl is-active --quiet mikrotik-2fa; then
        echo "Iniciando Mikrotik 2FA..."
        sudo systemctl start mikrotik-2fa
    else
        echo "✓ Mikrotik 2FA ya está ejecutándose"
    fi
    
    echo ""
}

# Función para mostrar información de red
show_network() {
    echo "Información de red:"
    echo "-------------------"
    
    # Obtener IP del contenedor
    CONTAINER_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || echo "No disponible")
    echo "IP del contenedor: $CONTAINER_IP"
    
    # Verificar puertos
    echo ""
    echo "Puertos disponibles:"
    if netstat -tlnp 2>/dev/null | grep -q ":5000"; then
        echo "✓ Puerto 5000 (Dashboard): ACTIVO"
    else
        echo "✗ Puerto 5000 (Dashboard): INACTIVO"
    fi
    
    if netstat -ulnp 2>/dev/null | grep -q ":1812"; then
        echo "✓ Puerto 1812 (RADIUS Auth): ACTIVO"
    else
        echo "✗ Puerto 1812 (RADIUS Auth): INACTIVO"
    fi
    
    if netstat -ulnp 2>/dev/null | grep -q ":1813"; then
        echo "✓ Puerto 1813 (RADIUS Accounting): ACTIVO"
    else
        echo "✗ Puerto 1813 (RADIUS Accounting): INACTIVO"
    fi
    
    echo ""
    echo "Accesos:"
    echo "  Dashboard: http://$CONTAINER_IP:5000"
    echo "  Usuario: admin"
    echo "  Contraseña: admin123"
    echo ""
}

# Función para mostrar logs
show_logs() {
    echo "Últimos logs del sistema:"
    echo "------------------------"
    
    echo "Logs de Mikrotik 2FA (últimas 10 líneas):"
    sudo journalctl -u mikrotik-2fa --no-pager -n 10 2>/dev/null || echo "No hay logs disponibles"
    
    echo ""
    echo "Logs de FreeRADIUS (últimas 5 líneas):"
    sudo journalctl -u freeradius --no-pager -n 5 2>/dev/null || echo "No hay logs disponibles"
    
    echo ""
}

# Función para desarrollo local
start_dev() {
    echo "Iniciando en modo desarrollo..."
    echo "Presiona Ctrl+C para detener"
    echo ""
    
    # Activar entorno virtual
    if [ -d "venv" ]; then
        source venv/bin/activate
        echo "✓ Entorno virtual activado"
    else
        echo "✗ Entorno virtual no encontrado. Ejecuta install_lxc.sh primero."
        exit 1
    fi
    
    # Iniciar aplicación en modo desarrollo
    python app.py
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  start     - Iniciar servicios"
    echo "  stop      - Detener servicios"
    echo "  restart   - Reiniciar servicios"
    echo "  status    - Mostrar estado de servicios"
    echo "  network   - Mostrar información de red"
    echo "  logs      - Mostrar logs recientes"
    echo "  dev       - Iniciar en modo desarrollo"
    echo "  help      - Mostrar esta ayuda"
    echo ""
    echo "Sin argumentos: muestra estado y opciones"
    echo ""
}

# Función principal
main() {
    case "${1:-status}" in
        start)
            start_services
            show_status
            show_network
            ;;
        stop)
            echo "Deteniendo servicios..."
            sudo systemctl stop mikrotik-2fa freeradius
            show_status
            ;;
        restart)
            echo "Reiniciando servicios..."
            sudo systemctl restart freeradius mikrotik-2fa
            sleep 3
            show_status
            show_network
            ;;
        status)
            show_status
            show_network
            ;;
        network)
            show_network
            ;;
        logs)
            show_logs
            ;;
        dev)
            start_dev
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Comando desconocido: $1"
            echo ""
            show_help
            ;;
    esac
}

# Ejecutar función principal
main "$@"
