#!/usr/bin/env python3
"""
Script para crear el usuario administrador inicial del sistema
Ejecutar: python3 create_admin.py
"""

import os
import sys
from werkzeug.security import generate_password_hash
from datetime import datetime

# Agregar el directorio actual al path para importar la aplicación
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, db, User

def create_admin_user():
    """Crear usuario administrador inicial"""
    
    with app.app_context():
        # Crear tablas si no existen
        db.create_all()
        
        # Verificar si ya existe un usuario admin
        admin = User.query.filter_by(username='admin').first()
        
        if admin:
            print("El usuario 'admin' ya existe.")
            choice = input("¿Deseas cambiar la contraseña? (s/n): ").lower()
            if choice == 's':
                password = input("Ingresa nueva contraseña para admin: ")
                admin.set_password(password)
                admin.generate_totp_secret()
                db.session.commit()
                print("Contraseña actualizada exitosamente.")
            return
        
        # Crear usuario admin
        username = 'admin'
        password = input("Ingresa contraseña para el usuario administrador: ")
        
        admin = User(username=username)
        admin.set_password(password)
        admin.generate_totp_secret()
        admin.totp_enabled = False  # Inicialmente sin 2FA
        
        db.session.add(admin)
        db.session.commit()
        
        print(f"Usuario administrador '{username}' creado exitosamente.")
        print("Puedes acceder al dashboard en: http://localhost:5000")
        print("\nPara habilitar 2FA:")
        print("1. Inicia sesión en el dashboard")
        print("2. Haz clic en el ícono QR del usuario admin")
        print("3. Escanea el código con Google Authenticator")
        print("4. Habilita el 2FA desde el dashboard")

if __name__ == '__main__':
    create_admin_user()
