from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, login_user, logout_user, login_required, current_user, UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
import pyotp
import qrcode
import io
import base64
import os
from datetime import datetime
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'tu-clave-secreta-muy-segura')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Modelo de Usuario
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    totp_secret = db.Column(db.String(32), nullable=True)
    totp_enabled = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def get_totp_uri(self):
        if self.totp_secret:
            return pyotp.totp.TOTP(self.totp_secret).provisioning_uri(
                name=self.username,
                issuer_name="Mikrotik 2FA"
            )
        return None
    
    def generate_totp_secret(self):
        self.totp_secret = pyotp.random_base32()
        return self.totp_secret
    
    def verify_totp(self, token):
        if not self.totp_secret:
            return False
        totp = pyotp.TOTP(self.totp_secret)
        return totp.verify(token, valid_window=1)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def index():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return render_template('login.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        user = User.query.filter_by(username=username).first()
        
        if user and user.check_password(password):
            login_user(user)
            user.last_login = datetime.utcnow()
            db.session.commit()
            return redirect(url_for('dashboard'))
        else:
            flash('Credenciales inválidas')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    users = User.query.all()
    return render_template('dashboard.html', users=users)

@app.route('/create_user', methods=['GET', 'POST'])
@login_required
def create_user():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        if User.query.filter_by(username=username).first():
            flash('El usuario ya existe')
            return render_template('create_user.html')
        
        user = User(username=username)
        user.set_password(password)
        user.generate_totp_secret()
        
        db.session.add(user)
        db.session.commit()
        
        flash(f'Usuario {username} creado exitosamente')
        return redirect(url_for('dashboard'))
    
    return render_template('create_user.html')

@app.route('/user/<int:user_id>/qr')
@login_required
def generate_qr(user_id):
    user = User.query.get_or_404(user_id)
    if not user.totp_secret:
        flash('Usuario no tiene TOTP configurado')
        return redirect(url_for('dashboard'))
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(user.get_totp_uri())
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    img_io = io.BytesIO()
    img.save(img_io, format='PNG')
    img_io.seek(0)
    
    img_base64 = base64.b64encode(img_io.getvalue()).decode()
    
    return render_template('qr_code.html', user=user, qr_code=img_base64)

@app.route('/user/<int:user_id>/enable_totp', methods=['POST'])
@login_required
def enable_totp(user_id):
    user = User.query.get_or_404(user_id)
    token = request.form['token']
    
    if user.verify_totp(token):
        user.totp_enabled = True
        db.session.commit()
        flash(f'TOTP habilitado para {user.username}')
    else:
        flash('Código TOTP inválido')
    
    return redirect(url_for('dashboard'))

@app.route('/user/<int:user_id>/disable_totp', methods=['POST'])
@login_required
def disable_totp(user_id):
    user = User.query.get_or_404(user_id)
    user.totp_enabled = False
    db.session.commit()
    flash(f'TOTP deshabilitado para {user.username}')
    return redirect(url_for('dashboard'))

@app.route('/user/<int:user_id>/delete', methods=['POST'])
@login_required
def delete_user(user_id):
    user = User.query.get_or_404(user_id)
    username = user.username
    db.session.delete(user)
    db.session.commit()
    flash(f'Usuario {username} eliminado')
    return redirect(url_for('dashboard'))

# API para FreeRADIUS
@app.route('/api/auth', methods=['POST'])
def api_auth():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    totp_token = data.get('totp_token')
    
    user = User.query.filter_by(username=username).first()
    
    if not user or not user.check_password(password):
        return jsonify({'result': 'REJECT'})
    
    if user.totp_enabled:
        if not totp_token or not user.verify_totp(totp_token):
            return jsonify({'result': 'REJECT'})
    
    return jsonify({'result': 'ACCEPT'})

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
