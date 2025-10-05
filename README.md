# Mikrotik 2FA con FreeRADIUS y Google Authenticator

Este proyecto implementa un sistema de autenticación de dos factores (2FA) para dispositivos Mikrotik usando FreeRADIUS, TOTP (Time-based One-Time Password) compatible con Google Authenticator, y un dashboard web desarrollado en Flask para la gestión de usuarios.

## Características

- ✅ Dashboard web para gestión de usuarios
- ✅ Generación automática de códigos QR para Google Authenticator
- ✅ Autenticación TOTP compatible con Google Authenticator
- ✅ Integración con FreeRADIUS
- ✅ API REST para autenticación
- ✅ Base de datos SQLite para almacenamiento
- ✅ Interfaz web moderna y responsiva

## Arquitectura del Sistema

```
[Usuario] → [Mikrotik] → [FreeRADIUS] → [API Flask] → [Base de Datos]
                ↓
        [Google Authenticator] ← [Dashboard Web]
```

## Instalación

### Requisitos del Sistema

- Python 3.8 o superior
- FreeRADIUS 3.x
- Flask y dependencias (ver requirements.txt)
- Dispositivo Mikrotik con RouterOS

### Hardware

- Servidor con Linux/Unix (Ubuntu/Debian recomendado)
- Acceso de red entre Mikrotik y el servidor FreeRADIUS

## Instalación

### 1. Clonar/Descargar el Proyecto

```bash
cd /opt
git clone <tu-repositorio> mikrotik-2fa
cd mikrotik-2fa
```

### 2. Instalación Automática (Recomendado)

#### Para contenedores LXC Ubuntu:
```bash
sudo bash install_lxc.sh
```

#### Para instalación estándar:
```bash
sudo bash install.sh
```

### 3. Instalación Manual

#### Instalar Dependencias de Python

```bash
pip3 install -r requirements.txt
```

#### Configurar Variables de Entorno

```bash
cp env_example.txt .env
nano .env
```

Edita el archivo `.env` con tus configuraciones:

```env
SECRET_KEY=tu-clave-secreta-muy-segura
FLASK_API_URL=http://localhost:5000/api/auth
RADIUS_SECRET=secreto_radius_cambiarlo
```

#### Crear Usuario Administrador

```bash
python3 create_admin.py
```

#### Inicializar la Base de Datos

```bash
python3 app.py
```

La aplicación creará automáticamente la base de datos SQLite en el primer arranque.

## 🐳 Instalación en Contenedores LXC

### Prerrequisitos LXC

- Contenedor LXC con Ubuntu 20.04+ o 22.04+
- Acceso root al contenedor
- Conectividad de red entre LXC y Mikrotik
- Al menos 512MB RAM y 2GB espacio en disco

### Instalación Rápida en LXC

```bash
# 1. Clonar el proyecto en el contenedor LXC
git clone <tu-repositorio> mikrotik-2fa
cd mikrotik-2fa

# 2. Instalación automática optimizada para LXC
sudo bash install_lxc.sh

# 3. Iniciar servicios
sudo systemctl start freeradius mikrotik-2fa

# 4. Verificar instalación
bash start_lxc.sh status
```

### Gestión en LXC

```bash
# Ver estado de servicios
bash start_lxc.sh status

# Iniciar servicios
bash start_lxc.sh start

# Ver logs
bash start_lxc.sh logs

# Modo desarrollo
bash start_lxc.sh dev

# Información de red
bash start_lxc.sh network
```

### Configuración de Red LXC

El script detectará automáticamente la IP del contenedor. Para configurar Mikrotik:

1. **Obtener IP del contenedor:**
   ```bash
   bash start_lxc.sh network
   ```

2. **Configurar Mikrotik:**
   - Servidor RADIUS: `IP_DEL_CONTENEDOR`
   - Secreto: `radius_secret_2fa_mikrotik`
   - Importar: `mikrotik_config_lxc.rsc`

### Ventajas de LXC

- ✅ **Aislamiento**: Sistema completamente aislado
- ✅ **Portabilidad**: Fácil migración entre hosts
- ✅ **Recursos**: Uso eficiente de recursos
- ✅ **Seguridad**: Entorno controlado
- ✅ **Backup**: Backup completo del contenedor

### 5. Instalar y Configurar FreeRADIUS

#### En Ubuntu/Debian:

```bash
sudo apt update
sudo apt install freeradius freeradius-utils
```

#### Configurar FreeRADIUS:

1. Copiar archivos de configuración:

```bash
sudo cp freeradius/sites-available/default /etc/freeradius/3.0/sites-available/
sudo cp freeradius/modules/python /etc/freeradius/3.0/mods-available/
```

2. Habilitar el módulo Python:

```bash
sudo ln -sf /etc/freeradius/3.0/mods-available/python /etc/freeradius/3.0/mods-enabled/
```

3. Hacer ejecutable el script de autenticación:

```bash
sudo chmod +x freeradius/radius_auth.py
```

4. Configurar el cliente RADIUS:

```bash
sudo nano /etc/freeradius/3.0/clients.conf
```

Agregar la configuración del cliente Mikrotik:

```
client mikrotik {
    ipaddr = 192.168.1.1/24
    secret = secreto_radius_cambiarlo
    shortname = mikrotik
}
```

5. Reiniciar FreeRADIUS:

```bash
sudo systemctl restart freeradius
sudo systemctl enable freeradius
```

### 6. Configurar Mikrotik

Ejecutar los comandos del archivo `mikrotik_config.rsc` en el terminal de Mikrotik:

```bash
# Importar configuración
/import mikrotik_config.rsc
```

O ejecutar manualmente los comandos necesarios.

## Uso del Sistema

### 1. Iniciar la Aplicación

```bash
python3 app.py
```

### 2. Acceder al Dashboard

Abrir navegador en: `http://localhost:5000`

### 3. Crear Usuario

1. Hacer clic en "Crear Usuario"
2. Ingresar nombre de usuario y contraseña
3. El sistema generará automáticamente el secreto TOTP

### 4. Configurar 2FA en el Móvil

1. Hacer clic en el ícono QR del usuario
2. Escanear el código QR con Google Authenticator
3. En el dashboard, hacer clic en el ícono de candado
4. Ingresar el código de 6 dígitos de Google Authenticator
5. El 2FA quedará habilitado

### 5. Autenticación en Mikrotik

Los usuarios pueden conectarse usando:

- **Usuario**: El nombre creado en el dashboard
- **Contraseña**: La contraseña establecida
- **Código 2FA**: El código de 6 dígitos de Google Authenticator

## Estructura del Proyecto

```
mikrotik-2fa/
├── app.py                    # Aplicación principal Flask
├── requirements.txt          # Dependencias Python
├── create_admin.py           # Script para crear usuario administrador
├── install.sh               # Script de instalación automatizada
├── install_lxc.sh           # Script de instalación para LXC Ubuntu
├── start_lxc.sh             # Script de gestión para LXC
├── templates/               # Plantillas HTML
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── create_user.html
│   └── qr_code.html
├── freeradius/             # Configuraciones FreeRADIUS
│   ├── radius_auth.py      # Script de autenticación
│   ├── sites-available/default
│   └── modules/python
├── mikrotik_config.rsc     # Configuración Mikrotik (estándar)
├── mikrotik_config_lxc.rsc # Configuración Mikrotik (LXC)
├── env_example.txt         # Variables de entorno ejemplo
└── README.md              # Este archivo
```

## API Endpoints

### Dashboard Web

- `GET /` - Página de login
- `POST /login` - Autenticación de administrador
- `GET /dashboard` - Panel principal
- `GET /create_user` - Formulario crear usuario
- `POST /create_user` - Crear usuario
- `GET /user/<id>/qr` - Generar código QR
- `POST /user/<id>/enable_totp` - Habilitar 2FA
- `POST /user/<id>/disable_totp` - Deshabilitar 2FA
- `POST /user/<id>/delete` - Eliminar usuario

### API REST

- `POST /api/auth` - Autenticación para FreeRADIUS

#### Formato de petición API:

```json
{
    "username": "usuario",
    "password": "contraseña",
    "totp_token": "123456"
}
```

#### Respuesta:

```json
{
    "result": "ACCEPT|REJECT",
    "message": "Mensaje opcional"
}
```

## Troubleshooting

### Problemas Comunes

1. **FreeRADIUS no autentica usuarios**
   - Verificar que el servicio esté ejecutándose: `sudo systemctl status freeradius`
   - Revisar logs: `sudo tail -f /var/log/freeradius/radius.log`
   - Verificar conectividad de red entre Mikrotik y servidor

2. **Error en el script Python de FreeRADIUS**
   - Verificar permisos: `sudo chmod +x radius_auth.py`
   - Verificar que Python3 esté instalado
   - Revisar la ruta en `/etc/freeradius/3.0/mods-available/python`

3. **Dashboard no carga**
   - Verificar que Flask esté ejecutándose
   - Revisar logs de la aplicación
   - Verificar que el puerto 5000 esté disponible

4. **Códigos QR no se generan**
   - Verificar que la librería `qrcode` esté instalada
   - Revisar permisos de escritura en el directorio

### Logs Importantes

- FreeRADIUS: `/var/log/freeradius/radius.log`
- Flask: Salida de consola donde ejecutas `python3 app.py`
- Mikrotik: `/log print` en terminal Mikrotik

## Seguridad

### Recomendaciones

1. **Cambiar secretos por defecto**
   - Modificar `SECRET_KEY` en `.env`
   - Cambiar `RADIUS_SECRET` en configuración FreeRADIUS

2. **Configurar firewall**
   - Abrir solo puertos necesarios (1812, 1813, 5000)
   - Restringir acceso por IP si es posible

3. **Usar HTTPS en producción**
   - Configurar certificados SSL
   - Usar proxy reverso (nginx/apache)

4. **Backups regulares**
   - Respaldo de base de datos SQLite
   - Configuraciones de FreeRADIUS

## Desarrollo

### Agregar Nuevas Funcionalidades

1. **Nuevos campos de usuario**: Modificar modelo `User` en `app.py`
2. **Nuevas páginas**: Crear plantillas en `templates/`
3. **API endpoints**: Agregar rutas en `app.py`

### Testing

```bash
# Probar autenticación RADIUS
echo "User-Name = testuser
User-Password = testpass
TOTP-Token = 123456" | radclient -x localhost auth secreto_radius
```

## Licencia

Este proyecto está bajo licencia MIT. Ver archivo LICENSE para más detalles.

## Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## Soporte

Para soporte técnico o preguntas:

- Crear un issue en el repositorio
- Revisar la documentación de FreeRADIUS
- Consultar logs del sistema

---

**Nota**: Este sistema está diseñado para uso en redes privadas. Para implementaciones en producción, considera aspectos adicionales de seguridad, escalabilidad y monitoreo.
