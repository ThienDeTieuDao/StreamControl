#!/bin/bash
# StreamLite Auto-Installation Script for VPS
# This script will perform a fully automated installation of StreamLite
# on a clean Ubuntu/Debian VPS or dedicated server.

# =============================================================================
# Color codes for better readability
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# Configuration Variables - Change these as needed
# =============================================================================
APP_DIR="/opt/streamlite"
DOMAIN_NAME="yourdomain.com"  # Change this to your actual domain
USE_POSTGRESQL=true           # Set to false to use MySQL
ADMIN_USERNAME="admin"
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD=$(openssl rand -hex 8)  # Random password, will be shown at the end
DB_NAME="streamlite"
DB_USER="streamlite"
DB_PASS=$(openssl rand -hex 12)  # Random secure password
DB_HOST="localhost"
SESSION_SECRET=$(openssl rand -hex 24)  # Random secure session key

# System user to run the application
SYS_USER="streamlite"
SYS_GROUP="streamlite"

# Flag to control whether to install Nginx and configure it
INSTALL_NGINX=true
# Flag to control whether to set up SSL with Let's Encrypt
SETUP_SSL=true

# =============================================================================
# Helper Functions
# =============================================================================
print_banner() {
    echo -e "${BLUE}"
    echo " _______ _________ _______  _______  _______  _       _________ _______ "
    echo "(  ____ \\__   __/(  ____ )(  ____ \(  ___  )( \      \__   __/(  ____ \\"
    echo "| (    \/   ) (   | (    )|| (    \/| (   ) || (         ) (   | (    \/"
    echo "| (_____    | |   | (____)|| (__    | (___) || |         | |   | (__    "
    echo "(_____  )   | |   |     __)|  __)   |  ___  || |         | |   |  __)   "
    echo "      ) |   | |   | (\ (   | (      | (   ) || |         | |   | (      "
    echo "/\____) |   | |   | ) \ \__| (____/\| )   ( || (____/\___) (___| (____/\\"
    echo "\_______)   )_(   |/   \__/(_______/|/     \|(_______/\_______/(_______/"
    echo "                                                                         "
    echo -e "${NC}"
    echo -e "${CYAN}Automated VPS Installation Script${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_step() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Check command function
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# Progress animation
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    # Convert to lowercase
    OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
    
    # Detect package manager
    if [[ "$OS" == *"ubuntu"* ]] || [[ "$OS" == *"debian"* ]]; then
        PKG_MANAGER="apt-get"
    elif [[ "$OS" == *"centos"* ]] || [[ "$OS" == *"rhel"* ]] || [[ "$OS" == *"fedora"* ]]; then
        PKG_MANAGER="yum"
    else
        print_error "Unsupported operating system: $OS"
        exit 1
    fi
    
    print_info "Detected OS: $OS $VER with package manager: $PKG_MANAGER"
}

# Create a non-root user to run the application
create_system_user() {
    print_step "Creating system user"
    
    if id "$SYS_USER" &>/dev/null; then
        print_info "User $SYS_USER already exists"
    else
        print_info "Creating user $SYS_USER"
        useradd -m -s /bin/bash $SYS_USER
        print_success "User $SYS_USER created"
    fi
    
    # Set up the application directory
    if [ ! -d "$APP_DIR" ]; then
        print_info "Creating application directory $APP_DIR"
        mkdir -p $APP_DIR
    fi
    
    # Set ownership
    chown -R $SYS_USER:$SYS_GROUP $APP_DIR
}

# Install required system packages
install_system_packages() {
    print_step "Installing system packages"
    
    # Update package lists
    print_info "Updating package lists..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        apt-get update -q &> /dev/null &
        show_progress $!
        print_success "Package lists updated"
        
        # Install required packages
        print_info "Installing required packages..."
        apt-get install -y python3 python3-pip python3-venv python3-dev git nginx curl \
        build-essential libssl-dev libffi-dev libpq-dev wget supervisor &> /dev/null &
        show_progress $!
        
        # Database packages
        if [ "$USE_POSTGRESQL" = true ]; then
            print_info "Installing PostgreSQL..."
            apt-get install -y postgresql postgresql-contrib &> /dev/null &
            show_progress $!
        else
            print_info "Installing MySQL..."
            apt-get install -y mysql-server default-libmysqlclient-dev &> /dev/null &
            show_progress $!
        fi
        
        # FFmpeg for media processing
        print_info "Installing FFmpeg..."
        apt-get install -y ffmpeg &> /dev/null &
        show_progress $!
        
    elif [ "$PKG_MANAGER" = "yum" ]; then
        yum update -y -q &> /dev/null &
        show_progress $!
        print_success "Package lists updated"
        
        # EPEL repository
        print_info "Installing EPEL repository..."
        yum install -y epel-release &> /dev/null &
        show_progress $!
        
        # Install required packages
        print_info "Installing required packages..."
        yum install -y python3 python3-pip python3-devel git nginx curl \
        gcc openssl-devel bzip2-devel libffi-devel wget supervisor &> /dev/null &
        show_progress $!
        
        # Database packages
        if [ "$USE_POSTGRESQL" = true ]; then
            print_info "Installing PostgreSQL..."
            yum install -y postgresql postgresql-server postgresql-contrib postgresql-devel &> /dev/null &
            show_progress $!
            
            # Initialize the database if not already done
            if [ ! -f /var/lib/pgsql/data/pg_hba.conf ]; then
                print_info "Initializing PostgreSQL database..."
                postgresql-setup initdb &> /dev/null
            fi
        else
            print_info "Installing MySQL..."
            yum install -y mysql-server mysql-devel &> /dev/null &
            show_progress $!
        fi
        
        # FFmpeg for media processing
        print_info "Installing FFmpeg..."
        yum install -y ffmpeg ffmpeg-devel &> /dev/null &
        show_progress $!
    fi
    
    print_success "System packages installed"
}

# Setup and start database service
setup_database_service() {
    print_step "Setting up database service"
    
    if [ "$USE_POSTGRESQL" = true ]; then
        # Start PostgreSQL service
        print_info "Starting PostgreSQL service..."
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            systemctl start postgresql &> /dev/null
            systemctl enable postgresql &> /dev/null
        else
            systemctl start postgresql &> /dev/null
            systemctl enable postgresql &> /dev/null
        fi
        
        # Wait a bit for the service to fully start
        sleep 3
        
        # Check if PostgreSQL is running
        if systemctl is-active --quiet postgresql; then
            print_success "PostgreSQL service started and enabled"
        else
            print_error "Failed to start PostgreSQL service"
            exit 1
        fi
    else
        # Start MySQL service
        print_info "Starting MySQL service..."
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            systemctl start mysql &> /dev/null
            systemctl enable mysql &> /dev/null
        else
            systemctl start mysqld &> /dev/null
            systemctl enable mysqld &> /dev/null
        fi
        
        # Wait a bit for the service to fully start
        sleep 3
        
        # Check if MySQL is running
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            if systemctl is-active --quiet mysql; then
                print_success "MySQL service started and enabled"
            else
                print_error "Failed to start MySQL service"
                exit 1
            fi
        else
            if systemctl is-active --quiet mysqld; then
                print_success "MySQL service started and enabled"
            else
                print_error "Failed to start MySQL service"
                exit 1
            fi
        fi
    fi
}

# Create database and user
create_database() {
    print_step "Creating database and database user"
    
    if [ "$USE_POSTGRESQL" = true ]; then
        print_info "Creating PostgreSQL database and user..."
        
        # Create the database and user
        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" &> /dev/null
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';" &> /dev/null
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" &> /dev/null
        
        # Grant necessary permissions
        sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;" &> /dev/null
        sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;" &> /dev/null
        sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;" &> /dev/null
        sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;" &> /dev/null
        sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;" &> /dev/null
        
        print_success "PostgreSQL database and user created"
    else
        print_info "Creating MySQL database and user..."
        
        # Create the database and user
        mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" &> /dev/null
        mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" &> /dev/null
        mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" &> /dev/null
        mysql -e "FLUSH PRIVILEGES;" &> /dev/null
        
        print_success "MySQL database and user created"
    fi
}

# Clone or download StreamLite
get_streamlite() {
    print_step "Setting up StreamLite application"
    
    # Check if git is installed
    if check_command git; then
        print_info "Cloning StreamLite repository..."
        git clone https://github.com/your-repo/streamlite.git $APP_DIR/temp &> /dev/null || {
            print_error "Failed to clone repository. Using local files instead."
            # If git clone fails, copy local files
            cp -R . $APP_DIR/temp
        }
    else
        print_info "Git not available. Copying local files..."
        cp -R . $APP_DIR/temp
    fi
    
    # Move files from temp directory to APP_DIR
    cp -R $APP_DIR/temp/* $APP_DIR/
    rm -rf $APP_DIR/temp
    
    # Create necessary directories
    mkdir -p $APP_DIR/uploads
    mkdir -p $APP_DIR/uploads/thumbnails
    mkdir -p $APP_DIR/static/error_pages
    mkdir -p $APP_DIR/instance
    mkdir -p $APP_DIR/logs
    
    # Set proper permissions
    chown -R $SYS_USER:$SYS_GROUP $APP_DIR
    chmod -R 755 $APP_DIR
    chmod -R 777 $APP_DIR/uploads
    
    print_success "StreamLite files set up"
}

# Create the Python virtual environment and install dependencies
setup_python_env() {
    print_step "Setting up Python environment"
    
    # Create and activate virtual environment
    print_info "Creating virtual environment..."
    su - $SYS_USER -c "cd $APP_DIR && python3 -m venv venv" &> /dev/null
    
    # Install dependencies
    print_info "Installing Python dependencies..."
    
    # Determine which requirements.txt to use
    if [ "$USE_POSTGRESQL" = true ]; then
        # Use PostgreSQL requirements
        if [ -f "$APP_DIR/requirements.txt.template" ]; then
            cp $APP_DIR/requirements.txt.template $APP_DIR/requirements.txt
        else
            # Create default requirements file
            cat > $APP_DIR/requirements.txt << EOF
flask>=2.0.0
flask-login>=0.6.2
flask-sqlalchemy>=3.0.0
gunicorn>=20.1.0
psycopg2-binary>=2.9.3
python-dotenv>=1.0.0
werkzeug>=2.0.0
sqlalchemy>=1.4.0
email-validator>=1.1.3
ffmpeg-python>=0.2.0
pillow>=9.0.0
EOF
        fi
    else
        # Use MySQL requirements
        if [ -f "$APP_DIR/requirements.txt.mysql.template" ]; then
            cp $APP_DIR/requirements.txt.mysql.template $APP_DIR/requirements.txt
        else
            # Create default MySQL requirements file
            cat > $APP_DIR/requirements.txt << EOF
flask>=2.0.0
flask-login>=0.6.2
flask-sqlalchemy>=3.0.0
gunicorn>=20.1.0
mysqlclient>=2.1.0
python-dotenv>=1.0.0
werkzeug>=2.0.0
sqlalchemy>=1.4.0
email-validator>=1.1.3
ffmpeg-python>=0.2.0
pillow>=9.0.0
EOF
        fi
    fi
    
    # Install dependencies
    su - $SYS_USER -c "cd $APP_DIR && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt" &> /dev/null &
    show_progress $!
    
    print_success "Python dependencies installed"
}

# Create the .env configuration file
create_env_file() {
    print_step "Creating environment configuration"
    
    print_info "Creating .env file..."
    
    # Determine database URL format
    if [ "$USE_POSTGRESQL" = true ]; then
        DB_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
    else
        DB_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
    fi
    
    # Create the .env file
    cat > $APP_DIR/.env << EOF
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
EOF
    
    # Set proper permissions for .env file
    chmod 600 $APP_DIR/.env
    chown $SYS_USER:$SYS_GROUP $APP_DIR/.env
    
    print_success ".env file created"
}

# Create required static files
create_static_files() {
    print_step "Creating static files"
    
    # Create robots.txt
    print_info "Creating robots.txt..."
    cat > $APP_DIR/static/robots.txt << EOF
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /user/
Disallow: /login
Disallow: /register
Disallow: /profile
Disallow: /dashboard
Disallow: /settings
EOF
    
    # Create 404 error page
    print_info "Creating 404.html error page..."
    cat > $APP_DIR/static/error_pages/404.html << EOF
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Page Not Found</title>
    <link href="https://cdn.replit.com/agent/bootstrap-agent-dark-theme.min.css" rel="stylesheet">
    <style>
        .error-container {
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
        }
        .error-code {
            font-size: 8rem;
            font-weight: bold;
            margin-bottom: 0;
        }
        .error-message {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
    </style>
</head>
<body>
    <div class="container error-container">
        <h1 class="error-code">404</h1>
        <p class="error-message">Oops! We couldn't find the page you're looking for.</p>
        <a href="/" class="btn btn-primary">Go Home</a>
    </div>
</body>
</html>
EOF
    
    # Create 500 error page
    print_info "Creating 500.html error page..."
    cat > $APP_DIR/static/error_pages/500.html << EOF
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>500 - Server Error</title>
    <link href="https://cdn.replit.com/agent/bootstrap-agent-dark-theme.min.css" rel="stylesheet">
    <style>
        .error-container {
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
        }
        .error-code {
            font-size: 8rem;
            font-weight: bold;
            margin-bottom: 0;
        }
        .error-message {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
    </style>
</head>
<body>
    <div class="container error-container">
        <h1 class="error-code">500</h1>
        <p class="error-message">Oops! Something went wrong on our server.</p>
        <a href="/" class="btn btn-primary">Go Home</a>
    </div>
</body>
</html>
EOF
    
    # Create maintenance page
    print_info "Creating maintenance.html page..."
    cat > $APP_DIR/static/maintenance.html << EOF
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Maintenance</title>
    <link href="https://cdn.replit.com/agent/bootstrap-agent-dark-theme.min.css" rel="stylesheet">
    <style>
        .maintenance-container {
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
        }
        .maintenance-title {
            font-size: 3rem;
            font-weight: bold;
            margin-bottom: 1rem;
        }
        .maintenance-message {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
    </style>
</head>
<body>
    <div class="container maintenance-container">
        <h1 class="maintenance-title">Site Under Maintenance</h1>
        <p class="maintenance-message">We're currently performing scheduled maintenance. Please check back shortly.</p>
    </div>
</body>
</html>
EOF
    
    # Set proper permissions
    chown -R $SYS_USER:$SYS_GROUP $APP_DIR/static
    
    print_success "Static files created"
}

# Initialize the database with tables and admin user
initialize_database() {
    print_step "Initializing database"
    
    print_info "Creating database tables and admin user..."
    
    # Run the initialize script non-interactively
    su - $SYS_USER -c "cd $APP_DIR && source venv/bin/activate && python initialize.py --non-interactive" || {
        print_error "Failed to initialize database automatically. Trying with explicit admin credentials..."
        
        # Try an alternative method using a temporary script
        cat > $APP_DIR/init_temp.py << EOF
#!/usr/bin/env python3
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Import necessary components
from app import app, db
from models import User, Category, SiteSettings
from werkzeug.security import generate_password_hash

with app.app_context():
    # Create tables
    db.create_all()
    
    # Create admin user
    admin_user = User(
        username="$ADMIN_USERNAME",
        email="$ADMIN_EMAIL",
        password_hash=generate_password_hash("$ADMIN_PASSWORD"),
        is_admin=True,
        created_at=datetime.utcnow(),
        last_login=datetime.utcnow()
    )
    
    db.session.add(admin_user)
    db.session.commit()
    
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
    
    # Create default site settings
    default_settings = SiteSettings(
        site_name="StreamLite",
        primary_color="#3b71ca",
        accent_color="#14a44d",
        footer_text="© StreamLite | Lightweight Streaming Platform"
    )
    
    db.session.add(default_settings)
    db.session.commit()
    
    print("Database initialization completed successfully.")
EOF
        
        # Make the script executable and run it
        chmod +x $APP_DIR/init_temp.py
        chown $SYS_USER:$SYS_GROUP $APP_DIR/init_temp.py
        su - $SYS_USER -c "cd $APP_DIR && source venv/bin/activate && python init_temp.py"
        
        # Clean up
        rm $APP_DIR/init_temp.py
    }
    
    print_success "Database initialized with tables and admin user"
}

# Create the Gunicorn systemd service
create_gunicorn_service() {
    print_step "Creating Gunicorn service"
    
    print_info "Creating systemd service file..."
    
    # Create the service file
    cat > /etc/systemd/system/streamlite.service << EOF
[Unit]
Description=StreamLite Gunicorn Service
After=network.target

[Service]
User=$SYS_USER
Group=$SYS_GROUP
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 --log-level warning main:app
Restart=on-failure
RestartSec=5
SyslogIdentifier=streamlite

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd, enable and start the service
    print_info "Enabling and starting Gunicorn service..."
    systemctl daemon-reload
    systemctl enable streamlite &> /dev/null
    systemctl start streamlite &> /dev/null
    
    # Check if service started successfully
    if systemctl is-active --quiet streamlite; then
        print_success "Gunicorn service started and enabled"
    else
        print_error "Failed to start Gunicorn service. Please check logs with 'journalctl -u streamlite'"
    fi
}

# Configure Nginx
configure_nginx() {
    if [ "$INSTALL_NGINX" = true ]; then
        print_step "Configuring Nginx"
        
        print_info "Creating Nginx configuration..."
        
        # Create Nginx configuration file
        cat > /etc/nginx/sites-available/streamlite << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    # Document root
    root $APP_DIR;
    
    # Static files
    location /static {
        alias $APP_DIR/static;
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }
    
    # Uploads
    location /uploads {
        alias $APP_DIR/uploads;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    # For the error pages
    location = /404.html {
        root $APP_DIR/static/error_pages;
        internal;
    }
    
    location = /500.html {
        root $APP_DIR/static/error_pages;
        internal;
    }
    
    # For the robots.txt file
    location = /robots.txt {
        root $APP_DIR/static;
        try_files \$uri =404;
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
    
    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /500.html;
}
EOF
        
        # Enable the site by creating a symbolic link
        if [ -d "/etc/nginx/sites-enabled" ]; then
            # Debian/Ubuntu style
            ln -sf /etc/nginx/sites-available/streamlite /etc/nginx/sites-enabled/
            
            # Remove default site if it exists
            if [ -f "/etc/nginx/sites-enabled/default" ]; then
                rm /etc/nginx/sites-enabled/default
            fi
        else
            # CentOS/RHEL style
            ln -sf /etc/nginx/sites-available/streamlite /etc/nginx/conf.d/streamlite.conf
        fi
        
        # Test Nginx configuration
        nginx -t &> /dev/null
        if [ $? -eq 0 ]; then
            print_success "Nginx configuration is valid"
            
            # Restart Nginx
            print_info "Restarting Nginx..."
            systemctl restart nginx &> /dev/null
            
            # Check if Nginx restarted successfully
            if systemctl is-active --quiet nginx; then
                print_success "Nginx restarted successfully"
            else
                print_error "Failed to restart Nginx. Please check logs with 'journalctl -u nginx'"
            fi
        else
            print_error "Nginx configuration is invalid. Please check with 'nginx -t'"
        fi
    else
        print_info "Skipping Nginx configuration as per settings"
    fi
}

# Set up SSL with Let's Encrypt
setup_ssl_encryption() {
    if [ "$SETUP_SSL" = true ] && [ "$INSTALL_NGINX" = true ]; then
        print_step "Setting up SSL with Let's Encrypt"
        
        # Check if certbot is installed
        if ! check_command certbot; then
            print_info "Installing Certbot..."
            
            if [ "$PKG_MANAGER" = "apt-get" ]; then
                apt-get install -y certbot python3-certbot-nginx &> /dev/null &
                show_progress $!
            elif [ "$PKG_MANAGER" = "yum" ]; then
                yum install -y certbot python3-certbot-nginx &> /dev/null &
                show_progress $!
            fi
        fi
        
        # Obtain SSL certificate
        print_info "Obtaining SSL certificate for $DOMAIN_NAME..."
        certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL &> /dev/null
        
        if [ $? -eq 0 ]; then
            print_success "SSL certificate obtained successfully"
            
            # Set up auto-renewal
            print_info "Setting up automatic certificate renewal..."
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
            
            print_success "Automatic certificate renewal configured"
        else
            print_error "Failed to obtain SSL certificate. You can try manually with: 'certbot --nginx -d $DOMAIN_NAME'"
            print_info "Make sure your domain is pointing to this server's IP address."
        fi
    elif [ "$SETUP_SSL" = true ] && [ "$INSTALL_NGINX" = false ]; then
        print_info "Skipping SSL setup as Nginx installation was skipped"
    else
        print_info "Skipping SSL setup as per settings"
    fi
}

# Create a backup script
create_backup_script() {
    print_step "Creating backup script"
    
    print_info "Creating backup script..."
    
    # Create backup directory
    mkdir -p /opt/streamlite_backups
    
    # Create the backup script
    cat > /opt/backup_streamlite.sh << EOF
#!/bin/bash
# StreamLite Backup Script
# This script creates backups of the StreamLite database and files

# Configuration
BACKUP_DIR="/opt/streamlite_backups"
APP_DIR="$APP_DIR"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
USE_POSTGRESQL=$USE_POSTGRESQL

# Create backup directory for this run
BACKUP_PATH="\$BACKUP_DIR/backup_\$TIMESTAMP"
mkdir -p "\$BACKUP_PATH"

# Backup the database
if [ "\$USE_POSTGRESQL" = true ]; then
    PGPASSWORD="\$DB_PASS" pg_dump -U "\$DB_USER" -d "\$DB_NAME" | gzip > "\$BACKUP_PATH/database.sql.gz"
else
    mysqldump -u "\$DB_USER" -p"\$DB_PASS" "\$DB_NAME" | gzip > "\$BACKUP_PATH/database.sql.gz"
fi

# Backup application files
tar -czf "\$BACKUP_PATH/app_files.tar.gz" -C "\$(dirname "\$APP_DIR")" "\$(basename "\$APP_DIR")" --exclude="venv"

# Backup uploads separately
tar -czf "\$BACKUP_PATH/uploads.tar.gz" -C "\$APP_DIR" "uploads"

# Create a readme file with backup info
cat > "\$BACKUP_PATH/README.txt" << EOL
StreamLite Backup
Created: \$(date)
Database: $DB_NAME
Application Directory: $APP_DIR

To restore the database:
- PostgreSQL: gunzip -c database.sql.gz | psql -U $DB_USER -d $DB_NAME
- MySQL: gunzip -c database.sql.gz | mysql -u $DB_USER -p $DB_NAME

To restore files:
- tar -xzf app_files.tar.gz -C /path/to/destination
- tar -xzf uploads.tar.gz -C /path/to/$APP_DIR
EOL

# Remove backups older than 30 days
find "\$BACKUP_DIR" -type d -name "backup_*" -mtime +30 -exec rm -rf {} \;

echo "Backup completed: \$BACKUP_PATH"
EOF
    
    # Make the script executable
    chmod +x /opt/backup_streamlite.sh
    
    # Create a cron job for daily backups
    print_info "Setting up daily backup cron job..."
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup_streamlite.sh") | crontab -
    
    print_success "Backup script and cron job created"
}

# Create documentation
create_documentation() {
    print_step "Creating documentation"
    
    print_info "Creating administration documentation..."
    
    # Create a documentation file
    mkdir -p $APP_DIR/docs
    
    cat > $APP_DIR/docs/ADMIN_GUIDE.md << EOF
# StreamLite Administration Guide

## Installation Summary

StreamLite has been automatically installed with the following configuration:

- Application directory: $APP_DIR
- System user: $SYS_USER
- Database type: $([ "$USE_POSTGRESQL" = true ] && echo "PostgreSQL" || echo "MySQL")
- Database name: $DB_NAME
- Database user: $DB_USER

## Administrative Access

### Admin Login Credentials

- Username: $ADMIN_USERNAME
- Email: $ADMIN_EMAIL
- Password: $ADMIN_PASSWORD

**IMPORTANT:** Please change this password immediately after first login!

### Access the Admin Panel

1. Go to http://$DOMAIN_NAME/login
2. Log in with the admin credentials above
3. Navigate to the admin panel via the user menu

## Server Management

### Service Control

To manage the StreamLite service:

\`\`\`bash
# Start the service
sudo systemctl start streamlite

# Stop the service
sudo systemctl stop streamlite

# Restart the service
sudo systemctl restart streamlite

# Check service status
sudo systemctl status streamlite

# View logs
sudo journalctl -u streamlite
\`\`\`

### Nginx Control

\`\`\`bash
# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
\`\`\`

## Backup and Restore

A backup script has been created at /opt/backup_streamlite.sh that runs daily at 2:00 AM.

### Manual Backup

To create a manual backup:

\`\`\`bash
sudo /opt/backup_streamlite.sh
\`\`\`

### Restore from Backup

See instructions in the README.txt file of each backup directory in /opt/streamlite_backups.

## Configuration

### Environment Variables

Environment variables are stored in $APP_DIR/.env

### Maintenance Mode

To put the site in maintenance mode:

1. Edit the Nginx configuration:
\`\`\`bash
sudo nano /etc/nginx/sites-available/streamlite
\`\`\`

2. Add the following at the top of the server block:
\`\`\`nginx
return 503;
error_page 503 /maintenance.html;
\`\`\`

3. Restart Nginx:
\`\`\`bash
sudo systemctl restart nginx
\`\`\`

4. To disable maintenance mode, remove those lines and restart Nginx.

## Troubleshooting

### Database Connection Issues

If the application cannot connect to the database:

1. Verify the database service is running:
\`\`\`bash
sudo systemctl status $([ "$USE_POSTGRESQL" = true ] && echo "postgresql" || echo "mysql")
\`\`\`

2. Check the database connection settings in $APP_DIR/.env

### Permission Issues

If you encounter permission errors:

\`\`\`bash
# Reset ownership of all files
sudo chown -R $SYS_USER:$SYS_GROUP $APP_DIR

# Set proper permissions for uploads directory
sudo chmod -R 777 $APP_DIR/uploads

# Set proper permissions for .env file
sudo chmod 600 $APP_DIR/.env
sudo chown $SYS_USER:$SYS_GROUP $APP_DIR/.env
\`\`\`

### Application Errors

Check the application logs:

\`\`\`bash
sudo tail -f $APP_DIR/logs/gunicorn.log
\`\`\`

## Updating StreamLite

To update StreamLite:

1. Stop the service:
\`\`\`bash
sudo systemctl stop streamlite
\`\`\`

2. Create a backup:
\`\`\`bash
sudo /opt/backup_streamlite.sh
\`\`\`

3. Update the files (via git or manual upload)

4. Restart the service:
\`\`\`bash
sudo systemctl start streamlite
\`\`\`

## Support

For additional support, please refer to the documentation in $APP_DIR/docs
or visit the StreamLite project website.
EOF
    
    # Create a troubleshooting guide
    cat > $APP_DIR/docs/TROUBLESHOOTING.md << EOF
# StreamLite Troubleshooting Guide

## Common Issues and Solutions

### Application Won't Start

If the StreamLite service won't start:

1. Check the service status:
\`\`\`bash
sudo systemctl status streamlite
\`\`\`

2. Check the logs:
\`\`\`bash
sudo journalctl -u streamlite
\`\`\`

3. Try running Gunicorn directly:
\`\`\`bash
cd $APP_DIR
sudo -u $SYS_USER $APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:5000 main:app
\`\`\`

4. Check Python dependencies:
\`\`\`bash
sudo -u $SYS_USER $APP_DIR/venv/bin/pip list
\`\`\`

### Database Connection Errors

If you see database connection errors:

1. Verify the database service is running:
\`\`\`bash
sudo systemctl status $([ "$USE_POSTGRESQL" = true ] && echo "postgresql" || echo "mysql")
\`\`\`

2. Test the connection manually:
\`\`\`bash
# For PostgreSQL
sudo -u $SYS_USER PGPASSWORD="$DB_PASS" psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -c "SELECT 1;"

# For MySQL
sudo -u $SYS_USER mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" -e "SELECT 1;"
\`\`\`

3. Check the database connection settings in $APP_DIR/.env

### Permission Issues

If you encounter permission errors:

1. Reset ownership of all files:
\`\`\`bash
sudo chown -R $SYS_USER:$SYS_GROUP $APP_DIR
\`\`\`

2. Set proper permissions for uploads directory:
\`\`\`bash
sudo chmod -R 777 $APP_DIR/uploads
\`\`\`

3. For PostgreSQL specific permission issues:
\`\`\`bash
# Grant schema permissions
sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;"
\`\`\`

### Nginx Connection Issues

If Nginx won't connect to the application:

1. Check if Gunicorn is running:
\`\`\`bash
sudo systemctl status streamlite
\`\`\`

2. Test if port 5000 is open:
\`\`\`bash
sudo netstat -tulpn | grep 5000
\`\`\`

3. Test the application directly:
\`\`\`bash
curl http://localhost:5000/
\`\`\`

4. Check Nginx configuration:
\`\`\`bash
sudo nginx -t
\`\`\`

5. Restart Nginx:
\`\`\`bash
sudo systemctl restart nginx
\`\`\`

### SSL Certificate Issues

If you have problems with SSL:

1. Check certbot status:
\`\`\`bash
sudo certbot certificates
\`\`\`

2. Test SSL renewal:
\`\`\`bash
sudo certbot renew --dry-run
\`\`\`

3. Manually obtain a new certificate:
\`\`\`bash
sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME
\`\`\`

### Media Upload Issues

If media uploads fail:

1. Check upload directory permissions:
\`\`\`bash
sudo chmod -R 777 $APP_DIR/uploads
\`\`\`

2. Verify FFmpeg is installed:
\`\`\`bash
ffmpeg -version
\`\`\`

3. Test FFmpeg functionality:
\`\`\`bash
sudo -u $SYS_USER ffmpeg -f lavfi -i testsrc=duration=5:size=1280x720:rate=30 $APP_DIR/test_video.mp4
\`\`\`

## Advanced Troubleshooting

### Reinstalling Python Dependencies

If you suspect Python dependency issues:

\`\`\`bash
sudo -u $SYS_USER bash -c "cd $APP_DIR && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt --force-reinstall"
\`\`\`

### Recreating Database

If you need to recreate the database:

1. Backup the current database:
\`\`\`bash
sudo /opt/backup_streamlite.sh
\`\`\`

2. Drop and recreate the database:
\`\`\`bash
# For PostgreSQL
sudo -u postgres psql -c "DROP DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# For MySQL
sudo mysql -e "DROP DATABASE $DB_NAME;"
sudo mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
\`\`\`

3. Reinitialize the database:
\`\`\`bash
sudo -u $SYS_USER bash -c "cd $APP_DIR && source venv/bin/activate && python initialize.py --non-interactive"
\`\`\`

### Checking Logs

Check all relevant logs:

1. Application logs:
\`\`\`bash
sudo tail -f $APP_DIR/logs/gunicorn.log
\`\`\`

2. Nginx logs:
\`\`\`bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
\`\`\`

3. System logs:
\`\`\`bash
sudo journalctl -u streamlite
sudo journalctl -u nginx
\`\`\`

## Contacting Support

If you continue to experience issues, please:

1. Gather all relevant logs
2. Take note of any error messages
3. Document the steps that lead to the issue
4. Refer to the project documentation or contact support

For additional support, please refer to the documentation in $APP_DIR/docs
or visit the StreamLite project website.
EOF
    
    # Set proper permissions
    chown -R $SYS_USER:$SYS_GROUP $APP_DIR/docs
    
    print_success "Documentation created"
}

# Print installation summary
print_installation_summary() {
    print_step "Installation Complete"
    
    echo -e "${GREEN}StreamLite has been successfully installed!${NC}"
    echo ""
    echo -e "${YELLOW}Installation Details:${NC}"
    echo -e "  ${BLUE}Application Directory:${NC} $APP_DIR"
    echo -e "  ${BLUE}System User:${NC} $SYS_USER"
    echo -e "  ${BLUE}Database Type:${NC} $([ "$USE_POSTGRESQL" = true ] && echo "PostgreSQL" || echo "MySQL")"
    echo -e "  ${BLUE}Database Name:${NC} $DB_NAME"
    echo -e "  ${BLUE}Domain Name:${NC} $DOMAIN_NAME"
    echo ""
    echo -e "${YELLOW}Admin Credentials:${NC}"
    echo -e "  ${BLUE}Username:${NC} $ADMIN_USERNAME"
    echo -e "  ${BLUE}Email:${NC} $ADMIN_EMAIL"
    echo -e "  ${BLUE}Password:${NC} $ADMIN_PASSWORD"
    echo ""
    echo -e "${YELLOW}Important Next Steps:${NC}"
    echo -e "  ${CYAN}1. Change the default admin password immediately after first login${NC}"
    echo -e "  ${CYAN}2. Update your domain DNS to point to this server${NC}"
    echo -e "  ${CYAN}3. Review the documentation at $APP_DIR/docs/ADMIN_GUIDE.md${NC}"
    echo ""
    echo -e "${YELLOW}Service Management:${NC}"
    echo -e "  ${CYAN}Start:${NC} sudo systemctl start streamlite"
    echo -e "  ${CYAN}Stop:${NC} sudo systemctl stop streamlite"
    echo -e "  ${CYAN}Restart:${NC} sudo systemctl restart streamlite"
    echo -e "  ${CYAN}Status:${NC} sudo systemctl status streamlite"
    echo ""
    echo -e "${YELLOW}Access Your Site:${NC}"
    echo -e "  ${CYAN}URL:${NC} http://$DOMAIN_NAME"
    echo -e "  ${CYAN}Admin URL:${NC} http://$DOMAIN_NAME/login"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  ${CYAN}Application Logs:${NC} sudo journalctl -u streamlite"
    echo -e "  ${CYAN}Nginx Logs:${NC} sudo tail -f /var/log/nginx/error.log"
    echo -e "  ${CYAN}Documentation:${NC} $APP_DIR/docs/TROUBLESHOOTING.md"
    echo ""
    echo -e "${GREEN}Thank you for installing StreamLite!${NC}"
}

# Main function to run the installation process
main() {
    # Check if script is run as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        echo "Please run with: sudo bash $0"
        exit 1
    fi
    
    # Print banner
    print_banner
    
    # Detect operating system
    detect_os
    
    # Start installation process
    create_system_user
    install_system_packages
    setup_database_service
    create_database
    get_streamlite
    setup_python_env
    create_env_file
    create_static_files
    initialize_database
    create_gunicorn_service
    configure_nginx
    setup_ssl_encryption
    create_backup_script
    create_documentation
    
    # Print installation summary
    print_installation_summary
}

# Execute main function
main