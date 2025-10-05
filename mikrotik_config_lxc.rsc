# Configuración de Mikrotik para 2FA con FreeRADIUS en LXC Ubuntu
# Ejecutar estos comandos en el terminal de Mikrotik

# 1. Configurar el servidor RADIUS (LXC Container)
/radius
add address=192.168.1.100 secret=radius_secret_2fa_mikrotik service=ppp,login,wireless \
    authentication-port=1812 accounting-port=1813 timeout=5s \
    comment="Servidor 2FA FreeRADIUS LXC"

# 2. Configurar AAA (Authentication, Authorization, Accounting)
/ppp aaa
set use-radius=yes

# 3. Configurar autenticación PPP
/ppp profile
add name=pppoe-profile local-address=192.168.100.1 \
    remote-address=pppoe-pool use-encryption=yes \
    use-compression=yes use-vj-compression=yes \
    only-one=yes

# 4. Crear pool de direcciones IP
/ip pool
add name=pppoe-pool ranges=192.168.100.10-192.168.100.254

# 5. Configurar interface PPPoE
/interface pppoe-server server
set default-profile=pppoe-profile authentication=pap,chap,mschap1,mschap2 \
    keepalive-timeout=disabled max-mru=1480 max-mtu=1480 mrru=disabled

# 6. Configurar autenticación para usuarios del sistema
/user aaa
set use-radius=yes

# 7. Configurar logging para debugging
/log
add topics=radius,info,debug

# 8. Configurar firewall para permitir RADIUS desde LXC
/ip firewall filter
add chain=input action=accept protocol=udp dst-port=1812,1813 \
    src-address=192.168.1.100 comment="Allow RADIUS from LXC container"

# 9. Configurar NAT si es necesario
/ip firewall nat
add chain=srcnat action=masquerade out-interface=pppoe-out1 comment="NAT for PPPoE"

# 10. Configuración adicional para LXC
# Permitir tráfico desde redes privadas comunes
/ip firewall filter
add chain=input action=accept protocol=udp dst-port=1812,1813 \
    src-address=10.0.0.0/8 comment="Allow RADIUS from 10.x.x.x networks"
add chain=input action=accept protocol=udp dst-port=1812,1813 \
    src-address=172.16.0.0/12 comment="Allow RADIUS from 172.16-31.x.x networks"

# Notas importantes para LXC:
# - Reemplaza 192.168.1.100 con la IP real del contenedor LXC
# - El secreto 'radius_secret_2fa_mikrotik' debe coincidir con el del contenedor
# - Ajusta las direcciones IP según tu red
# - Los usuarios se autenticarán usando el dashboard web en http://IP_LXC:5000
# - Para 2FA, los usuarios necesitan el código de Google Authenticator
# - El contenedor LXC debe tener acceso de red al Mikrotik
