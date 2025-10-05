#!/bin/bash

# Script de instalación simplificado para Mikrotik 2FA
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

# Obtener directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "Directorio del proyecto: $SCRIPT_DIR"

# Función para instalar paquetes
install_packages() {
    echo "Instalando paquetes necesarios..."
    
    if command -v apt >/dev/null 2>&1; then
        apt update
        apt install -y python3 python3-pip python3-venv freeradius freeradius-utils git curl
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y python3 python3-pip freeradius freeradius-utils git curl
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm python python-pip freeradius git curl
    else
        echo "Gestor de paquetes no soportado. Instala manualmente:"
        echo "  - Python 3.8+"
        echo "  - pip"
        echo "  - FreeRADIUS 3.x"
        exit 1
    fi
}

# Función para configurar Python
setup_python() {
    echo "Configurando Python..."
    
    cd "$SCRIPT_DIR"
    
    # Crear entorno virtual si no existe
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Activar entorno virtual e instalar dependencias
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    echo "Python configurado correctamente"
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
    chmod +x "$SCRIPT_DIR/freeradius/radius_auth.py"
    
    # Configurar cliente RADIUS
    echo "" >> /etc/freeradius/3.0/clients.conf
    echo "# Cliente Mikrotik para 2FA" >> /etc/freeradius/3.0/clients.conf
    echo "client mikrotik {" >> /etc/freeradius/3.0/clients.conf
    echo "    ipaddr = 192.168.1.0/24" >> /etc/freeradius/3.0/clients.conf
    echo "    secret = secreto_radius_cambiarlo" >> /etc/freeradius/3.0/clients.conf
    echo "    shortname = mikrotik" >> /etc/freeradius/3.0/clients.conf
    echo "}" >> /etc/freeradius/3.0/clients.conf
    
    # Cambiar propietario de archivos
    chown -R freerad:freerad /etc/freeradius/3.0/
    chown -R freerad:freerad "$SCRIPT_DIR/"
    
    # Habilitar y iniciar FreeRADIUS
    systemctl enable freeradius
    systemctl start freeradius
    
    echo "FreeRADIUS configurado correctamente"
}

# Función para crear usuario admin
create_admin() {
    echo "Creando usuario administrador..."
    
    cd "$SCRIPT_DIR"
    source venv/bin/activate
    
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
        print('Usuario admin creado con contraseña: admin123')
    else:
        print('Usuario admin ya existe')
"
}

# Función para configurar firewall
configure_firewall() {
    echo "Configurando firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 5000/tcp
        ufw allow 1812/udp
        ufw allow 1813/udp
        echo "Reglas UFW agregadas"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=5000/tcp
        firewall-cmd --permanent --add-port=1812/udp
        firewall-cmd --permanent --add-port=1813/udp
        firewall-cmd --reload
        echo "Reglas firewalld agregadas"
    else
        echo "No se detectó firewall. Configura manualmente:"
        echo "  Puerto 5000/tcp (Dashboard web)"
        echo "  Puerto 1812/udp (RADIUS auth)"
        echo "  Puerto 1813/udp (RADIUS accounting)"
    fi
}

# Función principal
main() {
    echo "Iniciando instalación desde: $SCRIPT_DIR"
    
    install_packages
    setup_python
    setup_freeradius
    create_admin
    configure_firewall
    
    echo ""
    echo "=========================================="
    echo "Instalación completada exitosamente!"
    echo "=========================================="
    echo ""
    echo "Para iniciar la aplicación:"
    echo "  cd $SCRIPT_DIR"
    echo "  source venv/bin/activate"
    echo "  python app.py"
    echo ""
    echo "Dashboard disponible en: http://localhost:5000"
    echo "Usuario: admin"
    echo "Contraseña: admin123"
    echo ""
    echo "Configuración adicional:"
    echo "1. Editar /etc/freeradius/3.0/clients.conf"
    echo "2. Cambiar 'secreto_radius_cambiarlo' por tu secreto"
    echo "3. Importar mikrotik_config.rsc en tu Mikrotik"
    echo ""
}

# Ejecutar instalación
main