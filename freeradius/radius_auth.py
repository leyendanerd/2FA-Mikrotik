#!/usr/bin/env python3
"""
Script de autenticación personalizado para FreeRADIUS
Este script se ejecuta cuando FreeRADIUS necesita autenticar un usuario
"""

import sys
import json
import requests
import os

# Configuración
FLASK_API_URL = os.getenv('FLASK_API_URL', 'http://localhost:5000/api/auth')

def read_radius_attributes():
    """Lee los atributos de autenticación de FreeRADIUS"""
    attrs = {}
    
    for line in sys.stdin:
        line = line.strip()
        if not line:
            break
            
        if '=' in line:
            key, value = line.split('=', 1)
            attrs[key.strip()] = value.strip()
    
    return attrs

def write_radius_response(result, message=""):
    """Escribe la respuesta de autenticación para FreeRADIUS"""
    if result == "ACCEPT":
        print("Reply-Message := \"Authentication successful\"")
        print("Service-Type := Framed-User")
    else:
        print("Reply-Message := \"Authentication failed: " + message + "\"")
    
    print("")
    sys.exit(0 if result == "ACCEPT" else 1)

def authenticate_user(username, password, totp_token=None):
    """Autentica el usuario usando la API de Flask"""
    try:
        data = {
            'username': username,
            'password': password
        }
        
        if totp_token:
            data['totp_token'] = totp_token
        
        response = requests.post(FLASK_API_URL, json=data, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            return result.get('result', 'REJECT'), result.get('message', '')
        else:
            return 'REJECT', f'API error: {response.status_code}'
            
    except requests.exceptions.RequestException as e:
        return 'REJECT', f'Connection error: {str(e)}'
    except Exception as e:
        return 'REJECT', f'Authentication error: {str(e)}'

def main():
    """Función principal"""
    # Leer atributos de FreeRADIUS
    attrs = read_radius_attributes()
    
    username = attrs.get('User-Name', '')
    password = attrs.get('User-Password', '')
    
    if not username or not password:
        write_radius_response('REJECT', 'Missing credentials')
    
    # Intentar autenticación sin TOTP primero
    result, message = authenticate_user(username, password)
    
    if result == "ACCEPT":
        write_radius_response('ACCEPT')
    
    # Si falla, intentar con TOTP si está disponible
    # En un escenario real, FreeRADIUS debería manejar esto con un segundo intento
    # Por simplicidad, asumimos que si el usuario tiene 2FA habilitado,
    # el token viene en el campo State o en un campo personalizado
    
    totp_token = attrs.get('State', '') or attrs.get('TOTP-Token', '')
    
    if totp_token and len(totp_token) == 6 and totp_token.isdigit():
        result, message = authenticate_user(username, password, totp_token)
        write_radius_response(result, message)
    else:
        write_radius_response('REJECT', 'TOTP token required')

if __name__ == '__main__':
    main()
