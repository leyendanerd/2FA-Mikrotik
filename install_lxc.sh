#!/bin/bash

# Script de instalación para Mikrotik 2FA con FreeRADIUS en LXC Ubuntu
# Ejecutar con: sudo bash install_lxc.sh

set -e

echo "=========================================="
echo "Instalador de Mikrotik 2FA con FreeRADIUS"
echo "Para contenedores LXC Ubuntu"
echo "=========================================="

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root (sudo)" 
   exit 1
fi

# Detectar si estamos en LXC
if [ -f /.dockerenv ] || [ -f /.lxcenv ] || grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
    echo "✓ Detectado contenedor LXC"
    IS_LXC=true
else
    echo "⚠ No se detectó contenedor LXC, continuando..."
    IS_LXC=false
fi

# Obtener directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "Directorio del proyecto: $SCRIPT_DIR"

# Función para instalar paquetes en Ubuntu
install_packages() {
    echo "Instalando paquetes necesarios para Ubuntu..."
    
    # Actualizar repositorios
    apt update
    
    # Instalar paquetes básicos
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        freeradius \
        freeradius-utils \
        freeradius-config \
        git \
        curl \
        wget \
        nano \
        htop \
        net-tools \
        iputils-ping \
        iptables-persistent
    
    echo "✓ Paquetes instalados correctamente"
}

# Función para configurar Python
setup_python() {
    echo "Configurando Python y entorno virtual..."
    
    cd "$SCRIPT_DIR"
    
    # Crear entorno virtual si no existe
    if [ ! -d "venv" ]; then
        echo "Creando entorno virtual Python..."
        python3 -m venv venv
    else
        echo "✓ Entorno virtual ya existe"
    fi
    
    # Activar entorno virtual e instalar dependencias
    echo "Instalando dependencias Python..."
    source venv/bin/activate
    
    # Actualizar pip
    pip install --upgrade pip
    
    # Instalar dependencias del proyecto
    pip install -r requirements.txt
    
    echo "✓ Python configurado correctamente"
}

# Función para configurar FreeRADIUS en LXC
setup_freeradius() {
    echo "Configurando FreeRADIUS para LXC..."
    
    # Detener FreeRADIUS si está ejecutándose
    systemctl stop freeradius 2>/dev/null || true
    
    # Backup de configuración original
    if [ ! -f /etc/freeradius/3.0/sites-available/default.backup ]; then
        cp /etc/freeradius/3.0/sites-available/default /etc/freeradius/3.0/sites-available/default.backup
    fi
    
    # Copiar nuestras configuraciones
    cp "$SCRIPT_DIR/freeradius/sites-available/default" /etc/freeradius/3.0/sites-available/
    cp "$SCRIPT_DIR/freeradius/modules/python" /etc/freeradius/3.0/mods-available/
    
    # Habilitar módulo Python
    ln -sf /etc/freeradius/3.0/mods-available/python /etc/freeradius/3.0/mods-enabled/
    
    # Hacer ejecutable el script de autenticación
    chmod +x "$SCRIPT_DIR/freeradius/radius_auth.py"
    
    # Configurar cliente RADIUS
    echo "" >> /etc/freeradius/3.0/clients.conf
    echo "# Cliente Mikrotik para 2FA" >> /etc/freeradius/3.0/clients.conf
    echo "client mikrotik {" >> /etc/freeradius/3.0/clients.conf
    echo "    ipaddr = 192.168.0.0/16" >> /etc/freeradius/3.0/clients.conf
    echo "    ipaddr = 10.0.0.0/8" >> /etc/freeradius/3.0/clients.conf
    echo "    ipaddr = 172.16.0.0/12" >> /etc/freeradius/3.0/clients.conf
    echo "    secret = radius_secret_2fa_mikrotik" >> /etc/freeradius/3.0/clients.conf
    echo "    shortname = mikrotik" >> /etc/freeradius/3.0/clients.conf
    echo "}" >> /etc/freeradius/3.0/clients.conf
    
    # Configurar permisos para LXC
    chown -R freerad:freerad /etc/freeradius/3.0/
    chown -R freerad:freerad "$SCRIPT_DIR/"
    
    # Crear directorio de logs si no existe
    mkdir -p /var/log/freeradius
    chown freerad:freerad /var/log/freeradius
    
    echo "✓ FreeRADIUS configurado para LXC"
}

# Función para configurar servicios en LXC
setup_services() {
    echo "Configurando servicios para LXC..."
    
    # Crear servicio systemd para la aplicación Flask
    cat > /etc/systemd/system/mikrotik-2fa.service << EOF
[Unit]
Description=Mikrotik 2FA Dashboard
After=network.target freeradius.service
Wants=freeradius.service

[Service]
Type=simple
User=freerad
Group=freerad
WorkingDirectory=$SCRIPT_DIR
Environment=PATH=$SCRIPT_DIR/venv/bin
Environment=PYTHONPATH=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/venv/bin/python app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Habilitar servicios
    systemctl daemon-reload
    systemctl enable freeradius
    systemctl enable mikrotik-2fa
    
    echo "✓ Servicios configurados para LXC"
}

# Función para configurar red en LXC
setup_network() {
    echo "Configurando red para LXC..."
    
    # En LXC, generalmente no necesitamos iptables complejos
    # Solo asegurarnos de que los puertos estén abiertos
    
    # Crear regla simple para iptables (si está disponible)
    if command -v iptables >/dev/null 2>&1; then
        # Permitir tráfico en los puertos necesarios
        iptables -I INPUT -p tcp --dport 5000 -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p udp --dport 1812 -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p udp --dport 1813 -j ACCEPT 2>/dev/null || true
        
        echo "✓ Reglas de firewall configuradas"
    else
        echo "⚠ iptables no disponible, configurar firewall manualmente si es necesario"
    fi
    
    echo "✓ Red configurada para LXC"
}

# Función para crear usuario admin
create_admin_user() {
    echo "Creando usuario administrador..."
    
    cd "$SCRIPT_DIR"
    source venv/bin/activate
    
    # Crear archivo .env si no existe
    if [ ! -f .env ]; then
        cp env_example.txt .env
        echo "✓ Archivo .env creado desde plantilla"
    fi
    
    python3 -c "
import os
os.environ['FLASK_APP'] = 'app.py'
from app import app, db, User

with app.app_context():
    db.create_all()
    admin = User.query.filter_by(username='admin').first()
    if not admin:
        admin = User(username='admin')
        admin.set_password('admin123')
        admin.generate_totp_secret()
        admin.totp_enabled = False
        db.session.add(admin)
        db.session.commit()
        print('✓ Usuario admin creado con contraseña: admin123')
    else:
        print('✓ Usuario admin ya existe')
"
}

# Función para verificar configuración LXC
verify_lxc_setup() {
    echo "Verificando configuración LXC..."
    
    # Verificar que los servicios estén habilitados
    if systemctl is-enabled freeradius >/dev/null 2>&1; then
        echo "✓ FreeRADIUS habilitado"
    else
        echo "⚠ FreeRADIUS no habilitado"
    fi
    
    if systemctl is-enabled mikrotik-2fa >/dev/null 2>&1; then
        echo "✓ Mikrotik 2FA habilitado"
    else
        echo "⚠ Mikrotik 2FA no habilitado"
    fi
    
    # Verificar puertos
    if netstat -tlnp 2>/dev/null | grep -q ":5000"; then
        echo "✓ Puerto 5000 disponible"
    fi
    
    if netstat -ulnp 2>/dev/null | grep -q ":1812"; then
        echo "✓ Puerto 1812 (RADIUS) disponible"
    fi
    
    echo "✓ Verificación completada"
}

# Función para mostrar información de red LXC
show_network_info() {
    echo "Información de red del contenedor LXC:"
    echo "----------------------------------------"
    
    # Mostrar IP del contenedor
    CONTAINER_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || echo "No disponible")
    echo "IP del contenedor: $CONTAINER_IP"
    
    # Mostrar interfaces de red
    echo "Interfaces de red:"
    ip addr show | grep -E "inet.*brd" | sed 's/^[ \t]*//'
    
    echo ""
    echo "Configuración para Mikrotik:"
    echo "  Servidor RADIUS: $CONTAINER_IP"
    echo "  Puerto Auth: 1812"
    echo "  Puerto Accounting: 1813"
    echo "  Secreto: radius_secret_2fa_mikrotik"
}

# Función principal
main() {
    echo "Iniciando instalación en contenedor LXC Ubuntu..."
    echo ""
    
    # Instalar paquetes necesarios
    install_packages
    
    # Configurar entorno Python
    setup_python
    
    # Configurar FreeRADIUS
    setup_freeradius
    
    # Configurar servicios
    setup_services
    
    # Configurar red
    setup_network
    
    # Crear usuario admin
    create_admin_user
    
    # Verificar configuración
    verify_lxc_setup
    
    echo ""
    echo "=========================================="
    echo "Instalación completada exitosamente!"
    echo "=========================================="
    echo ""
    
    # Mostrar información de red
    show_network_info
    
    echo ""
    echo "Próximos pasos:"
    echo "1. Iniciar servicios:"
    echo "   systemctl start freeradius"
    echo "   systemctl start mikrotik-2fa"
    echo ""
    echo "2. Acceder al dashboard:"
    echo "   http://$CONTAINER_IP:5000"
    echo "   Usuario: admin"
    echo "   Contraseña: admin123"
    echo ""
    echo "3. Configurar Mikrotik:"
    echo "   - Servidor RADIUS: $CONTAINER_IP"
    echo "   - Secreto: radius_secret_2fa_mikrotik"
    echo "   - Importar: mikrotik_config.rsc"
    echo ""
    echo "4. Comandos útiles:"
    echo "   - Ver logs: journalctl -u mikrotik-2fa -f"
    echo "   - Estado servicios: systemctl status freeradius mikrotik-2fa"
    echo "   - Reiniciar: systemctl restart mikrotik-2fa"
    echo ""
    echo "5. Para desarrollo local:"
    echo "   cd $SCRIPT_DIR"
    echo "   source venv/bin/activate"
    echo "   python app.py"
    echo ""
}

# Ejecutar instalación
main
