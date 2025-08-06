#!/bin/bash
# StreamLite VPS Installation Script
# This script sets up StreamLite platform on a VPS or dedicated server

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}           StreamLite Installation               ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_info() {
    echo -e "${YELLOW}$1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 could not be found. Please install it first."
        return 1
    fi
    return 0
}

# Check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root or with sudo privileges"
        exit 1
    fi
}

# Detect the hosting panel
detect_panel() {
    if [ -d "/usr/local/cpanel" ]; then
        echo "cpanel"
    elif [ -d "/www/server/panel" ]; then
        echo "aapanel"
    elif [ -d "/usr/local/CyberCP" ]; then
        echo "cyberpanel"
    else
        echo "unknown"
    fi
}

# Default configuration
APP_DIR=$(pwd)
VENV_DIR="${APP_DIR}/venv"
DB_NAME="streamlite"
DB_USER="streamlite_user"
DB_PASS=$(openssl rand -hex 12)
DB_HOST="localhost"
USE_POSTGRESQL=true
NGINX_CONFIG="${APP_DIR}/nginx_config.conf"

# Print header
print_header

# Check for required commands
print_info "Checking prerequisites..."
check_command python3 || { print_error "Python 3 is required but not installed. Please install Python 3.8 or higher."; exit 1; }
check_command pip3 || { print_error "pip3 is required but not installed."; exit 1; }

# Detect hosting panel
PANEL=$(detect_panel)
print_info "Detected hosting panel: $PANEL"

# Create requirements.txt if it doesn't exist
if [ ! -f "${APP_DIR}/requirements.txt" ]; then
    print_info "Creating requirements.txt..."
    
    # Check if template exists
    if [ -f "${APP_DIR}/requirements.txt.template" ]; then
        cp "${APP_DIR}/requirements.txt.template" "${APP_DIR}/requirements.txt"
        print_success "Created requirements.txt from template"
    else
        # Create from scratch if template doesn't exist
        cat > "${APP_DIR}/requirements.txt" << EOL
flask>=2.3.3
flask-login>=0.6.2
flask-sqlalchemy>=3.0.5
gunicorn>=21.2.0
psycopg2-binary>=2.9.7
python-dotenv>=1.0.0
werkzeug>=2.3.7
sqlalchemy>=2.0.20
email-validator>=2.0.0
ffmpeg-python>=0.2.0
pillow>=10.0.0
EOL
        print_success "Created requirements.txt"
    fi
fi

# Check for python3-venv
print_info "Checking for python3-venv package..."
# Try to detect distribution
if command -v apt-get &> /dev/null; then
    DISTRO="debian"
elif command -v yum &> /dev/null; then
    DISTRO="redhat"
else
    DISTRO="unknown"
fi

install_venv_package() {
    if [ "$DISTRO" == "debian" ]; then
        # Get Python version
        PY_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        print_info "Detected Python version: $PY_VERSION"
        
        if ! dpkg -l | grep -q "python$PY_VERSION-venv"; then
            print_info "Installing python$PY_VERSION-venv package..."
            apt-get update
            apt-get install -y "python$PY_VERSION-venv"
            if [ $? -eq 0 ]; then
                print_success "Installed python$PY_VERSION-venv package"
            else
                print_error "Failed to install python$PY_VERSION-venv. You may need to install it manually."
                print_info "Try: apt-get install python3-venv or python3.X-venv (where X is your Python version)"
            fi
        else
            print_info "python$PY_VERSION-venv is already installed"
        fi
    elif [ "$DISTRO" == "redhat" ]; then
        if ! rpm -qa | grep -q "python3-devel"; then
            print_info "Installing python3-devel package..."
            yum install -y python3-devel
            if [ $? -eq 0 ]; then
                print_success "Installed python3-devel package"
            else
                print_error "Failed to install python3-devel. You may need to install it manually."
                print_info "Try: yum install python3-devel"
            fi
        else
            print_info "python3-devel is already installed"
        fi
    else
        print_info "Could not detect package manager. Please ensure python3-venv or equivalent is installed."
    fi
}

# Only try to install if running as root
if [ "$EUID" -eq 0 ]; then
    install_venv_package
else
    print_info "Not running as root. Skipping automatic installation of python3-venv."
    print_info "If creating virtual environment fails, please install python3-venv manually:"
    print_info "For Debian/Ubuntu: sudo apt-get install python3-venv or python3.X-venv"
    print_info "For RHEL/CentOS: sudo yum install python3-devel"
fi

# Create virtual environment
print_info "Setting up virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR" || { 
        print_error "Failed to create virtual environment. Please install python3-venv package."
        print_info "For Debian/Ubuntu: sudo apt-get install python3-venv or python3.X-venv"
        print_info "For RHEL/CentOS: sudo yum install python3-devel"
        exit 1
    }
    print_success "Created virtual environment at $VENV_DIR"
else
    print_info "Virtual environment already exists at $VENV_DIR"
fi

# Activate virtual environment
source "${VENV_DIR}/bin/activate" || {
    print_error "Failed to activate virtual environment. Please check your installation."
    exit 1
}

# Install dependencies
print_info "Installing Python dependencies..."
pip3 install --upgrade pip
pip3 install -r "${APP_DIR}/requirements.txt"
print_success "Installed Python dependencies"

# Setup database based on detected panel
setup_database() {
    case "$PANEL" in
        "cpanel")
            if $USE_POSTGRESQL; then
                print_info "Setting up PostgreSQL database on cPanel..."
                # In cPanel, we'll use the PostgreSQL create database interface
                print_info "Please create a PostgreSQL database named '$DB_NAME' and user '$DB_USER' manually via cPanel interface."
                print_info "Then update the .env file with your credentials."
            else
                print_info "Setting up MySQL database on cPanel..."
                # In cPanel, we'll use the MySQL create database interface
                print_info "Please create a MySQL database named '$DB_NAME' and user '$DB_USER' manually via cPanel interface."
                print_info "Then update the .env file with your credentials."
            fi
            ;;
            
        "aapanel")
            if $USE_POSTGRESQL; then
                print_info "Setting up PostgreSQL database on AaPanel..."
                if command -v psql &> /dev/null; then
                    # Check if PostgreSQL is installed and create database
                    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
                    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
                    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
                    sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;" # For AaPanel PostgreSQL compatibility
                    # Also grant schema permissions explicitly
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;"
                    print_success "PostgreSQL database and user created successfully with proper permissions"
                else
                    print_error "PostgreSQL is not installed. Please install it first using AaPanel interface."
                fi
            else
                print_info "Setting up MySQL database on AaPanel..."
                if command -v mysql &> /dev/null; then
                    # Check if MySQL is installed and create database
                    mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
                    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
                    mysql -e "FLUSH PRIVILEGES;"
                    print_success "MySQL database and user created successfully"
                else
                    print_error "MySQL is not installed. Please install it first using AaPanel interface."
                fi
            fi
            ;;
            
        "cyberpanel")
            if $USE_POSTGRESQL; then
                print_info "Setting up PostgreSQL database on CyberPanel..."
                if command -v psql &> /dev/null; then
                    # Check if PostgreSQL is installed and create database
                    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
                    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
                    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
                    sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;" # For CyberPanel PostgreSQL compatibility
                    # Also grant schema permissions explicitly
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
                    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;"
                    print_success "PostgreSQL database and user created successfully with proper permissions"
                else
                    print_error "PostgreSQL is not installed. Please install it first using CyberPanel interface."
                fi
            else
                print_info "Setting up MySQL database on CyberPanel..."
                if command -v mysql &> /dev/null; then
                    # Check if MySQL is installed and create database
                    mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
                    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
                    mysql -e "FLUSH PRIVILEGES;"
                    print_success "MySQL database and user created successfully"
                else
                    print_error "MySQL is not installed. Please install it first using CyberPanel interface."
                fi
            fi
            ;;
            
        *)
            print_info "Manual database setup required..."
            print_info "Please create a database and user manually, then update the .env file with your credentials."
            ;;
    esac
}

# Create .env file
create_env_file() {
    if [ ! -f "${APP_DIR}/.env" ]; then
        print_info "Creating .env file..."
        
        # Determine database URL
        if $USE_POSTGRESQL; then
            DB_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
        else
            DB_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
        fi
        
        # Create random session key
        SESSION_SECRET=$(openssl rand -hex 24)
        
        cat > "${APP_DIR}/.env" << EOL
# StreamLite Environment Configuration

# Database Configuration
DATABASE_URL="${DB_URL}"
PGDATABASE="${DB_NAME}"
PGUSER="${DB_USER}"
PGPASSWORD="${DB_PASS}"
PGHOST="${DB_HOST}"
PGPORT=5432

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="${SESSION_SECRET}"
UPLOAD_FOLDER="${APP_DIR}/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO

# RTMP Settings
RTMP_SERVER=rtmp://localhost/live
EOL
        print_success "Created .env file with secure, random credentials"
    else
        print_info ".env file already exists. Skipping creation."
    fi
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p "${APP_DIR}/uploads/thumbnails"
    mkdir -p "${APP_DIR}/instance"
    chmod -R 755 "${APP_DIR}/uploads"
    print_success "Created upload directories"
}

# Create NGINX configuration
create_nginx_config() {
    print_info "Creating NGINX configuration file..."
    DOMAIN_NAME="yourdomain.com"  # Will be replaced by actual domain later
    
    cat > "$NGINX_CONFIG" << EOL
# StreamLite NGINX Configuration
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://${DOMAIN_NAME}\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};

    # SSL configuration
    ssl_certificate /path/to/your/fullchain.pem;
    ssl_certificate_key /path/to/your/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    # RTMP stats
    location /rtmp-stats {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
        allow 127.0.0.1;
        deny all;
    }

    # RTMP control
    location /rtmp-control {
        rtmp_control all;
        allow 127.0.0.1;
        deny all;
    }
    
    # Web app static files
    location /static {
        alias ${APP_DIR}/static;
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }
    
    # Media files
    location /uploads {
        alias ${APP_DIR}/uploads;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    # Proxy requests to Gunicorn
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}

# RTMP server configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        application live {
            live on;
            record off;
            
            # HLS streaming
            hls on;
            hls_path ${APP_DIR}/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # DASH streaming
            dash on;
            dash_path ${APP_DIR}/dash;
            dash_fragment 3;
            dash_playlist_length 60;
            
            # on_publish authentication handler
            on_publish http://127.0.0.1:5000/live/auth;
            on_publish_done http://127.0.0.1:5000/live/done;
        }
    }
}
EOL
    print_success "Created NGINX configuration file at $NGINX_CONFIG"
    print_info "You will need to update the server_name and SSL certificate paths in this file."
}

# Create a systemd service file for Gunicorn
create_service_file() {
    print_info "Creating systemd service file..."
    
    cat > "${APP_DIR}/streamlite.service" << EOL
[Unit]
Description=StreamLite Gunicorn Daemon
After=network.target

[Service]
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=${APP_DIR}
Environment="PATH=${VENV_DIR}/bin"
ExecStart=${VENV_DIR}/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 --log-level warning main:app
Restart=on-failure
RestartSec=5
SyslogIdentifier=streamlite

[Install]
WantedBy=multi-user.target
EOL
    print_success "Created systemd service file at ${APP_DIR}/streamlite.service"
    print_info "You can install it with: sudo cp ${APP_DIR}/streamlite.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now streamlite"
}

# Create a supervisor config for non-systemd environments
create_supervisor_config() {
    print_info "Creating supervisor configuration file..."
    
    cat > "${APP_DIR}/streamlite_supervisor.conf" << EOL
[program:streamlite]
command=${VENV_DIR}/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 --log-level warning main:app
directory=${APP_DIR}
user=$(whoami)
autostart=true
autorestart=true
stdout_logfile=${APP_DIR}/logs/gunicorn.log
stderr_logfile=${APP_DIR}/logs/gunicorn_error.log
environment=PATH="${VENV_DIR}/bin"

[supervisord]
EOL
    mkdir -p "${APP_DIR}/logs"
    print_success "Created supervisor configuration file at ${APP_DIR}/streamlite_supervisor.conf"
    print_info "You can install it with: sudo cp ${APP_DIR}/streamlite_supervisor.conf /etc/supervisor/conf.d/streamlite.conf && sudo supervisorctl reread && sudo supervisorctl update"
}

# Install FFmpeg if needed
install_ffmpeg() {
    print_info "Checking FFmpeg installation..."
    if ! command -v ffmpeg &> /dev/null; then
        print_info "FFmpeg not found. Attempting to install..."
        
        case "$PANEL" in
            "cpanel")
                print_error "FFmpeg is required but not installed. Please install it manually via cPanel or contact your server administrator."
                ;;
                
            "aapanel")
                if command -v apt-get &> /dev/null; then
                    apt-get update
                    apt-get install -y ffmpeg
                elif command -v yum &> /dev/null; then
                    yum install -y epel-release
                    yum install -y ffmpeg ffmpeg-devel
                else
                    print_error "Unable to install FFmpeg automatically. Please install it manually."
                fi
                ;;
                
            "cyberpanel")
                if command -v apt-get &> /dev/null; then
                    apt-get update
                    apt-get install -y ffmpeg
                elif command -v yum &> /dev/null; then
                    yum install -y epel-release
                    yum install -y ffmpeg ffmpeg-devel
                else
                    print_error "Unable to install FFmpeg automatically. Please install it manually."
                fi
                ;;
                
            *)
                if command -v apt-get &> /dev/null; then
                    apt-get update
                    apt-get install -y ffmpeg
                elif command -v yum &> /dev/null; then
                    yum install -y epel-release
                    yum install -y ffmpeg ffmpeg-devel
                else
                    print_error "Unable to install FFmpeg automatically. Please install it manually."
                fi
                ;;
        esac
        
        if command -v ffmpeg &> /dev/null; then
            print_success "FFmpeg installed successfully"
        else
            print_error "FFmpeg installation failed. Please install it manually."
        fi
    else
        print_success "FFmpeg is already installed"
    fi
}

# Main installation process
setup_database
create_env_file
create_directories
create_nginx_config
create_service_file
create_supervisor_config
install_ffmpeg

# Finalize installation
print_info "Creating initialization script..."
cat > "${APP_DIR}/initialize.py" << EOL
#!/usr/bin/env python3
"""
StreamLite Initialization Script
This script initializes the database and creates the initial admin user
"""

import os
import sys
import getpass
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Import necessary components
from app import db
from models import User, Category, SiteSettings
from werkzeug.security import generate_password_hash

def create_tables():
    """Create all database tables"""
    print("Creating database tables...")
    db.create_all()
    print("Database tables created successfully.")

def create_admin_user(username, email, password):
    """Create an admin user if one doesn't exist"""
    # Check if any admin user exists
    admin_exists = User.query.filter_by(is_admin=True).first()
    
    if admin_exists:
        print(f"Admin user already exists: {admin_exists.username}")
        return admin_exists
    
    # Create new admin user
    admin_user = User(
        username=username,
        email=email,
        password_hash=generate_password_hash(password),
        is_admin=True,
        created_at=datetime.utcnow(),
        last_login=datetime.utcnow()
    )
    
    db.session.add(admin_user)
    db.session.commit()
    print(f"Admin user created successfully: {username}")
    return admin_user

def create_default_categories():
    """Create default content categories if none exist"""
    # Check if any categories exist
    categories_exist = Category.query.first()
    
    if categories_exist:
        print("Categories already exist.")
        return
    
    # Create default categories
    default_categories = [
        {"name": "Entertainment", "description": "Entertainment videos", "icon": "film"},
        {"name": "Gaming", "description": "Gaming streams and videos", "icon": "gamepad"},
        {"name": "Music", "description": "Music videos and performances", "icon": "music"},
        {"name": "Education", "description": "Educational content", "icon": "graduation-cap"},
        {"name": "Sports", "description": "Sports videos and live streams", "icon": "futbol"},
        {"name": "News", "description": "News and current events", "icon": "newspaper"},
        {"name": "Technology", "description": "Technology tutorials and reviews", "icon": "laptop-code"}
    ]
    
    for cat_data in default_categories:
        category = Category(**cat_data)
        db.session.add(category)
    
    db.session.commit()
    print(f"Created {len(default_categories)} default categories.")

def create_site_settings():
    """Create default site settings if none exist"""
    # Check if settings exist
    settings_exist = SiteSettings.query.first()
    
    if settings_exist:
        print("Site settings already exist.")
        return
    
    # Create default settings
    default_settings = SiteSettings(
        site_name="StreamLite",
        primary_color="#3b71ca",
        accent_color="#14a44d",
        footer_text="© StreamLite | Lightweight Streaming Platform"
    )
    
    db.session.add(default_settings)
    db.session.commit()
    print("Default site settings created.")

def interactive_setup():
    """Run interactive setup process"""
    print("=" * 50)
    print("StreamLite Initialization")
    print("=" * 50)
    print("\nThis script will set up your StreamLite installation.")
    
    # Ask for admin user details
    print("\nPlease provide admin user details:")
    username = input("Admin username [admin]: ") or "admin"
    email = input("Admin email [admin@example.com]: ") or "admin@example.com"
    
    while True:
        password = getpass.getpass("Admin password: ")
        if len(password) < 8:
            print("Password must be at least 8 characters long.")
            continue
        
        confirm_password = getpass.getpass("Confirm password: ")
        if password != confirm_password:
            print("Passwords do not match. Please try again.")
            continue
        
        break
    
    # Confirm setup
    print("\nReady to initialize with the following settings:")
    print(f"- Admin Username: {username}")
    print(f"- Admin Email: {email}")
    
    confirm = input("\nProceed with initialization? [Y/n]: ") or "Y"
    if confirm.lower() not in ["y", "yes"]:
        print("Initialization cancelled.")
        return False
    
    # Create database tables
    create_tables()
    
    # Create admin user
    create_admin_user(username, email, password)
    
    # Create default categories
    create_default_categories()
    
    # Create default site settings
    create_site_settings()
    
    print("\n" + "=" * 50)
    print("Initialization Complete!")
    print("=" * 50)
    print("\nYou can now login with your admin credentials.")
    
    return True

def main():
    """Main function"""
    # Check if running in non-interactive mode
    if "--non-interactive" in sys.argv:
        create_tables()
        create_admin_user("admin", "admin@example.com", "streamlite_admin")
        create_default_categories()
        create_site_settings()
        print("Non-interactive initialization complete.")
        return
    
    # Otherwise, run interactive setup
    interactive_setup()

if __name__ == "__main__":
    main()
EOLp.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

# Create database tables
with app.app_context():
    db.create_all()
    
    # Check if admin user exists
    admin = models.User.query.filter_by(username='admin').first()
    if not admin:
        # Create admin user
        from werkzeug.security import generate_password_hash
        admin_password = os.environ.get('ADMIN_PASSWORD', 'streamlite_admin')
        admin = models.User(
            username='admin',
            email='admin@example.com',
            password_hash=generate_password_hash(admin_password),
            is_admin=True
        )
        db.session.add(admin)
        
        # Create default category
        default_category = models.Category(
            name='General',
            description='Default category for all media'
        )
        db.session.add(default_category)
        
        # Create site settings
        site_settings = models.SiteSettings(
            site_name='StreamLite',
            primary_color='#3b71ca',
            accent_color='#14a44d',
            enable_registration=True,
            max_upload_size_mb=500,
            footer_text='© StreamLite | Lightweight Streaming Platform'
        )
        db.session.add(site_settings)
        
        # Commit changes
        db.session.commit()
        print("Created admin user, default category, and site settings")
    else:
        print("Admin user already exists, skipping initialization")
EOL

print_success "Installation complete!"
print_info "Next steps:"
print_info "1. Update the NGINX configuration with your domain and SSL certificates"
print_info "2. Initialize the database with: source ${VENV_DIR}/bin/activate && python ${APP_DIR}/initialize.py"
print_info "3. Install the service file or supervisor config according to your hosting environment"
print_info "4. Start the application and access it through your web browser"

# Display credentials for user
print_info "===================="
print_info "Your database credentials:"
print_info "Database Name: $DB_NAME"
print_info "Database User: $DB_USER"
print_info "Database Password: $DB_PASS"
print_info "===================="

# Reference the detailed guides
print_info "For detailed, platform-specific installation instructions, please refer to:"
print_info "- HOSTING_GUIDES/cPanel_Installation.md - For cPanel installations"
print_info "- HOSTING_GUIDES/AaPanel_Installation.md - For AaPanel installations"
print_info "- HOSTING_GUIDES/Environment_Variables_Guide.md - For managing environment variables"
print_info "===================="
print_info "Remember to update your .env file using the methods described in the Environment_Variables_Guide.md!"