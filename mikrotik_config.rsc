# Configuración de Mikrotik para 2FA con FreeRADIUS
# Ejecutar estos comandos en el terminal de Mikrotik

# 1. Configurar el servidor RADIUS
/radius
add address=192.168.1.100 secret=tu_secreto_radius service=ppp,login,wireless \
    authentication-port=1812 accounting-port=1813 timeout=5s \
    comment="Servidor 2FA FreeRADIUS"

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

# 8. Crear usuario de prueba (opcional)
/ppp secret
add name=usuario_prueba password=contraseña123 profile=pppoe-profile \
    service=pppoe comment="Usuario de prueba para 2FA"

# Notas importantes:
# - Reemplaza 192.168.1.100 con la IP de tu servidor FreeRADIUS
# - Cambia 'tu_secreto_radius' por un secreto seguro
# - Ajusta las direcciones IP según tu red
# - Los usuarios se autenticarán usando el dashboard web
