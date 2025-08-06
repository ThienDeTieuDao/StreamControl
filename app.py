import os
import logging
from dotenv import load_dotenv
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase
from flask_login import LoginManager

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Create SQLAlchemy base class
class Base(DeclarativeBase):
    pass

# Initialize extensions
db = SQLAlchemy(model_class=Base)
login_manager = LoginManager()

# Create the app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key-change-in-production")

# Configure the database
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL")
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "pool_recycle": 300,
    "pool_pre_ping": True,
    "pool_size": 10,
    "max_overflow": 20
}
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Set upload folder and allowed extensions from config
from config import UPLOAD_FOLDER, MAX_CONTENT_LENGTH
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH

# Initialize the database
db.init_app(app)

# Initialize login manager
login_manager.init_app(app)
login_manager.login_view = 'auth.login'
login_manager.login_message_category = 'info'

# Create upload directory if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(os.path.join(UPLOAD_FOLDER, "thumbnails"), exist_ok=True)

with app.app_context():
    # Import models
    import models
    
    # Create database tables
    db.create_all()
    
    # Create default admin user if not exists
    from models import User
    from werkzeug.security import generate_password_hash
    
    admin_user = User.query.filter_by(username="admin").first()
    if not admin_user:
        logger.info("Creating default admin user")
        admin_user = User(
            username="admin",
            email="admin@localhost",
            password_hash=generate_password_hash("admin"),
            is_admin=True
        )
        db.session.add(admin_user)
        db.session.commit()

# Register blueprints
from routes.auth import auth_bp
from routes.media import media_bp
from routes.admin import admin_bp
from routes.live import live_bp
from routes.settings import settings_bp
from routes.webrtc import webrtc_bp, setup_routes

app.register_blueprint(auth_bp)
app.register_blueprint(media_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(live_bp)
app.register_blueprint(settings_bp)
app.register_blueprint(webrtc_bp)

# Additional route setup
setup_routes(app)

# Start WebRTC server as a separate process when in production
if os.environ.get('FLASK_ENV') != 'development':
    import subprocess
    import sys
    
    try:
        # Start the WebRTC server as a separate process
        webrtc_process = subprocess.Popen(
            [sys.executable, "webrtc_server.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        logger.info("WebRTC server started as a separate process on port 5443")
    except Exception as e:
        logger.error(f"Failed to start WebRTC server: {e}")

# Context processors
@app.context_processor
def inject_now():
    from datetime import datetime
    return {'now': datetime.utcnow()}

# Jinja2 filters
@app.template_filter('format_duration')
def format_duration_filter(seconds):
    from utils import format_duration
    return format_duration(seconds)

@app.template_filter('format_file_size')
def format_file_size_filter(size_bytes):
    from utils import format_file_size
    return format_file_size(size_bytes)

# User loader callback for Flask-Login
@login_manager.user_loader
def load_user(user_id):
    from models import User
    return User.query.get(int(user_id))
