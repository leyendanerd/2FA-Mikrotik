#!/bin/bash

# Script de instalación para Mikrotik 2FA con FreeRADIUS
# Ejecutar con: sudo bash install.sh

set -e

echo "=========================================="
echo "Instalador de Mikrotik 2FA con FreeRADIUS"
echo "=========================================="

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root (sudo)" 
   exit 1
fi

# Detectar distribución de Linux
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_MANAGER="apt"
elif [ -f /etc/redhat-release ]; then
    DISTRO="redhat"
    PKG_MANAGER="yum"
elif [ -f /etc/arch-release ]; then
    DISTRO="arch"
    PKG_MANAGER="pacman"
else
    echo "Distribución no soportada"
    exit 1
fi

echo "Distribución detectada: $DISTRO"

# Función para instalar paquetes
install_packages() {
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt update
        apt install -y python3 python3-pip python3-venv freeradius freeradius-utils git curl
    elif [ "$PKG_MANAGER" = "yum" ]; then
        yum update -y
        yum install -y python3 python3-pip freeradius freeradius-utils git curl
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman -Syu --noconfirm python python-pip freeradius git curl
    fi
}

# Función para configurar Python virtual environment
setup_python_env() {
    echo "Configurando entorno Python..."
    
    # Crear directorio para la aplicación
    mkdir -p /opt/mikrotik-2fa
    cd /opt/mikrotik-2fa
    
    # Copiar archivos del proyecto (asumiendo que se ejecuta desde el directorio del proyecto)
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    cp -r "$SCRIPT_DIR"/* /opt/mikrotik-2fa/
    
    # Crear entorno virtual
    python3 -m venv venv
    source venv/bin/activate
    
    # Instalar dependencias
    pip install -r requirements.txt
    
    echo "Entorno Python configurado correctamente"
}

# Función para configurar FreeRADIUS
setup_freeradius() {
    echo "Configurando FreeRADIUS..."
    
    # Detener FreeRADIUS si está ejecutándose
    systemctl stop freeradius 2>/dev/null || true
    
    # Copiar configuraciones
    cp freeradius/sites-available/default /etc/freeradius/3.0/sites-available/
    cp freeradius/modules/python /etc/freeradius/3.0/mods-available/
    
    # Habilitar módulo Python
    ln -sf /etc/freeradius/3.0/mods-available/python /etc/freeradius/3.0/mods-enabled/
    
    # Hacer ejecutable el script de autenticación
    chmod +x /opt/mikrotik-2fa/freeradius/radius_auth.py
    
    # Configurar cliente RADIUS (necesita edición manual)
    echo "" >> /etc/freeradius/3.0/clients.conf
    echo "# Cliente Mikrotik para 2FA" >> /etc/freeradius/3.0/clients.conf
    echo "client mikrotik {" >> /etc/freeradius/3.0/clients.conf
    echo "    ipaddr = 192.168.1.0/24" >> /etc/freeradius/3.0/clients.conf
    echo "    secret = secreto_radius_cambiarlo" >> /etc/freeradius/3.0/clients.conf
    echo "    shortname = mikrotik" >> /etc/freeradius/3.0/clients.conf
    echo "}" >> /etc/freeradius/3.0/clients.conf
    
    # Cambiar propietario de archivos
    chown -R freerad:freerad /etc/freeradius/3.0/
    chown -R freerad:freerad /opt/mikrotik-2fa/
    
    # Habilitar y iniciar FreeRADIUS
    systemctl enable freeradius
    systemctl start freeradius
    
    echo "FreeRADIUS configurado correctamente"
}

# Función para crear servicio systemd
create_systemd_service() {
    echo "Creando servicio systemd..."
    
    cat > /etc/systemd/system/mikrotik-2fa.service << EOF
[Unit]
Description=Mikrotik 2FA Dashboard
After=network.target

[Service]
Type=simple
User=freerad
Group=freerad
WorkingDirectory=/opt/mikrotik-2fa
Environment=PATH=/opt/mikrotik-2fa/venv/bin
ExecStart=/opt/mikrotik-2fa/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mikrotik-2fa
    systemctl start mikrotik-2fa
    
    echo "Servicio systemd creado correctamente"
}

# Función para configurar firewall
configure_firewall() {
    echo "Configurando firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian con UFW
        ufw allow 5000/tcp
        ufw allow 1812/udp
        ufw allow 1813/udp
        echo "Reglas UFW agregadas"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL con firewalld
        firewall-cmd --permanent --add-port=5000/tcp
        firewall-cmd --permanent --add-port=1812/udp
        firewall-cmd --permanent --add-port=1813/udp
        firewall-cmd --reload
        echo "Reglas firewalld agregadas"
    else
        echo "No se detectó firewall configurado. Configura manualmente:"
        echo "  Puerto 5000/tcp (Dashboard web)"
        echo "  Puerto 1812/udp (RADIUS auth)"
        echo "  Puerto 1813/udp (RADIUS accounting)"
    fi
}

# Función principal
main() {
    echo "Iniciando instalación..."
    
    # Instalar paquetes necesarios
    install_packages
    
    # Configurar entorno Python
    setup_python_env
    
    # Configurar FreeRADIUS
    setup_freeradius
    
    # Crear servicio systemd
    create_systemd_service
    
    # Configurar firewall
    configure_firewall
    
    echo ""
    echo "=========================================="
    echo "Instalación completada exitosamente!"
    echo "=========================================="
    echo ""
    echo "Próximos pasos:"
    echo "1. Configurar variables de entorno:"
    echo "   nano /opt/mikrotik-2fa/.env"
    echo ""
    echo "2. Configurar el cliente RADIUS en Mikrotik:"
    echo "   Editar /etc/freeradius/3.0/clients.conf"
    echo "   Cambiar 'secreto_radius_cambiarlo' por tu secreto"
    echo ""
    echo "3. Acceder al dashboard:"
    echo "   http://tu-servidor:5000"
    echo ""
    echo "4. Importar configuración en Mikrotik:"
    echo "   /import mikrotik_config.rsc"
    echo ""
    echo "Servicios:"
    echo "  - Dashboard web: systemctl status mikrotik-2fa"
    echo "  - FreeRADIUS: systemctl status freeradius"
    echo ""
    echo "Logs:"
    echo "  - Dashboard: journalctl -u mikrotik-2fa -f"
    echo "  - FreeRADIUS: tail -f /var/log/freeradius/radius.log"
    echo ""
}

# Ejecutar función principal
main
