#!/bin/bash
# RTMPS (RTMP over SSL) Setup Script for Streaming on hwosecurity.org

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}       RTMPS Setup for hwosecurity.org           ${NC}"
    echo -e "${BLUE}=================================================${NC}"
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

# Print header
print_header

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root or with sudo privileges"
    echo "Please run with: sudo bash $0"
    exit 1
fi

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
    print_info "Detected OS: Debian/Ubuntu"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    print_info "Detected OS: RHEL/CentOS"
else
    OS="unknown"
    print_info "Detected OS: Unknown"
fi

# Check for SSL certificates
if [ ! -d "/etc/letsencrypt/live/hwosecurity.org" ]; then
    print_error "SSL certificates for hwosecurity.org not found."
    print_info "Please run fix_ssl.sh first to set up SSL certificates."
    print_info "Continuing, but you'll need certificates for RTMPS to work properly."
else
    print_success "SSL certificates for hwosecurity.org found."
fi

# Install Nginx with RTMP module
print_info "Installing Nginx with RTMP module..."

if [ "$OS" = "debian" ]; then
    # For Debian/Ubuntu
    apt-get update
    
    # Check if Nginx is already installed
    if ! dpkg -l | grep -q "nginx"; then
        # Install dependencies
        apt-get install -y build-essential libpcre3-dev libssl-dev zlib1g-dev
        
        # Create a temporary directory
        mkdir -p /tmp/nginx-rtmp-build
        cd /tmp/nginx-rtmp-build
        
        # Download and extract Nginx
        print_info "Downloading Nginx..."
        wget https://nginx.org/download/nginx-1.22.1.tar.gz
        tar -xf nginx-1.22.1.tar.gz
        
        # Download RTMP module
        print_info "Downloading RTMP module..."
        git clone https://github.com/arut/nginx-rtmp-module.git
        
        # Configure and build Nginx with RTMP module
        cd nginx-1.22.1
        print_info "Configuring and building Nginx with RTMP module..."
        ./configure --prefix=/usr/local/nginx \
                    --with-http_ssl_module \
                    --with-http_v2_module \
                    --with-http_realip_module \
                    --with-http_gzip_static_module \
                    --with-stream \
                    --with-stream_ssl_module \
                    --add-module=../nginx-rtmp-module
        
        make
        make install
        
        # Create systemd service file
        cat > /etc/systemd/system/nginx.service << EOF
[Unit]
Description=Nginx with RTMP
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable nginx
        
        # Create symbolic links for nginx command
        ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx
        
        print_success "Nginx with RTMP module installed successfully."
    else
        print_info "Nginx is already installed. Adding RTMP module..."
        
        # Check if libnginx-mod-rtmp is available
        if apt-cache search libnginx-mod-rtmp | grep -q libnginx-mod-rtmp; then
            apt-get install -y libnginx-mod-rtmp
            print_success "RTMP module installed via apt."
        else
            print_info "RTMP module not available in apt. Building from source..."
            
            # Get currently installed Nginx version
            NGINX_VERSION=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
            
            # Create a temporary directory
            mkdir -p /tmp/nginx-rtmp-build
            cd /tmp/nginx-rtmp-build
            
            # Install dependencies
            apt-get install -y build-essential libpcre3-dev libssl-dev zlib1g-dev
            
            # Download and extract Nginx
            wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
            tar -xf "nginx-${NGINX_VERSION}.tar.gz"
            
            # Download RTMP module
            git clone https://github.com/arut/nginx-rtmp-module.git
            
            # Get existing configure arguments
            NGINX_CONFIG_ARGS=$(nginx -V 2>&1 | grep -o 'configure arguments:.*' | sed 's/configure arguments://')
            
            # Configure and build Nginx with RTMP module
            cd "nginx-${NGINX_VERSION}"
            ./configure $NGINX_CONFIG_ARGS --add-module=../nginx-rtmp-module
            make
            
            # Stop Nginx
            systemctl stop nginx
            
            # Backup existing nginx binary
            cp $(which nginx) $(which nginx).bak
            
            # Install new binary
            cp objs/nginx $(which nginx)
            
            # Start Nginx
            systemctl start nginx
            
            print_success "RTMP module added to existing Nginx installation."
        fi
    fi
elif [ "$OS" = "redhat" ]; then
    # For RHEL/CentOS
    
    # Install EPEL repository if needed
    if ! rpm -q epel-release &> /dev/null; then
        yum install -y epel-release
    fi
    
    # Install dependencies
    yum install -y gcc make pcre-devel openssl-devel zlib-devel git
    
    # Check if Nginx is already installed
    if ! rpm -q nginx &> /dev/null; then
        # Create a temporary directory
        mkdir -p /tmp/nginx-rtmp-build
        cd /tmp/nginx-rtmp-build
        
        # Download and extract Nginx
        print_info "Downloading Nginx..."
        wget https://nginx.org/download/nginx-1.22.1.tar.gz
        tar -xf nginx-1.22.1.tar.gz
        
        # Download RTMP module
        print_info "Downloading RTMP module..."
        git clone https://github.com/arut/nginx-rtmp-module.git
        
        # Configure and build Nginx with RTMP module
        cd nginx-1.22.1
        print_info "Configuring and building Nginx with RTMP module..."
        ./configure --prefix=/usr/local/nginx \
                    --with-http_ssl_module \
                    --with-http_v2_module \
                    --with-http_realip_module \
                    --with-http_gzip_static_module \
                    --with-stream \
                    --with-stream_ssl_module \
                    --add-module=../nginx-rtmp-module
        
        make
        make install
        
        # Create systemd service file
        cat > /etc/systemd/system/nginx.service << EOF
[Unit]
Description=Nginx with RTMP
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable nginx
        
        # Create symbolic links for nginx command
        ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx
        
        print_success "Nginx with RTMP module installed successfully."
    else
        print_error "Nginx is already installed. Manual configuration required."
        print_info "You'll need to rebuild Nginx with the RTMP module."
        print_info "See the documentation for details."
    fi
else
    print_error "Unsupported OS. Please install Nginx with RTMP module manually."
    exit 1
fi

# Create necessary directories for streaming
print_info "Creating directories for streaming..."
mkdir -p /opt/streamlite/uploads/live
mkdir -p /opt/streamlite/uploads/hls
mkdir -p /opt/streamlite/uploads/dash
chmod -R 777 /opt/streamlite/uploads

print_success "Directories created."

# Configure Nginx with RTMP and SSL
print_info "Configuring Nginx for RTMP and RTMPS..."

if [ "$OS" = "debian" ] && [ -d "/etc/nginx/conf.d" ]; then
    NGINX_CONF_DIR="/etc/nginx/conf.d"
elif [ "$OS" = "redhat" ] && [ -d "/etc/nginx/conf.d" ]; then
    NGINX_CONF_DIR="/etc/nginx/conf.d"
else
    NGINX_CONF_DIR="/usr/local/nginx/conf"
fi

# Create RTMP configuration file
cat > ${NGINX_CONF_DIR}/rtmp.conf << EOF
# RTMP configuration
rtmp {
    server {
        listen 1935; # Standard RTMP port
        chunk_size 4096;
        
        # RTMP application for live streaming
        application live {
            live on;
            record off;
            
            # Authentication based on stream key (simple implementation)
            on_publish http://localhost:5000/api/stream/authenticate;
            
            # HLS output
            hls on;
            hls_path /opt/streamlite/uploads/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # DASH output
            dash on;
            dash_path /opt/streamlite/uploads/dash;
            dash_fragment 3;
            dash_playlist_length 60;
        }
    }
}

# HTTPS server for HLS and DASH streams
server {
    listen 443 ssl http2;
    server_name hwosecurity.org www.hwosecurity.org;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/hwosecurity.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hwosecurity.org/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Serving HLS and DASH streams
    location /hls {
        alias /opt/streamlite/uploads/hls;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }
    
    location /dash {
        alias /opt/streamlite/uploads/dash;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        types {
            application/dash+xml mpd;
        }
    }
    
    # Standard Nginx configuration for serving your application
    # Proxy to your Flask application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files
    location /static {
        alias /opt/streamlite/static;
        expires 30d;
    }
    
    # Uploads
    location /uploads {
        alias /opt/streamlite/uploads;
        expires 7d;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name hwosecurity.org www.hwosecurity.org;
    return 301 https://\$host\$request_uri;
}
EOF

# Configure RTMPS (RTMP over SSL)
print_info "Setting up RTMPS (RTMP over SSL)..."

# Create stunnel configuration for RTMPS
apt-get install -y stunnel4

cat > /etc/stunnel/rtmps.conf << EOF
; RTMPS (RTMP over SSL) Configuration

; Certificate and key
cert = /etc/letsencrypt/live/hwosecurity.org/fullchain.pem
key = /etc/letsencrypt/live/hwosecurity.org/privkey.pem

; Global options
setuid = stunnel
setgid = stunnel
pid = /var/run/stunnel4/stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
compression = zlib

; RTMPS Server
[rtmps-server]
accept = 1936
connect = 1935
EOF

# Enable and start stunnel service
systemctl enable stunnel4
systemctl restart stunnel4

print_success "RTMPS configured using stunnel on port 1936."

# Test the configuration and restart Nginx
print_info "Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    print_info "Restarting Nginx..."
    systemctl restart nginx
    print_success "Nginx restarted successfully."
    
    # Verify services are running
    if systemctl is-active --quiet nginx && systemctl is-active --quiet stunnel4; then
        print_success "All services are running!"
    else
        print_error "Some services failed to start. Check the logs for details."
    fi
else
    print_error "Nginx configuration test failed. Please check the error and fix it."
fi

# Add streaming endpoint to StreamLite application
print_info "Updating StreamLite application configuration..."

# Check if .env file exists
if [ -f "/opt/streamlite/.env" ]; then
    # Update RTMP settings in .env
    if grep -q "RTMP_SERVER" "/opt/streamlite/.env"; then
        # Update existing RTMP_SERVER setting
        sed -i "s|RTMP_SERVER=.*|RTMP_SERVER=rtmps://hwosecurity.org:1936/live|g" /opt/streamlite/.env
    else
        # Add RTMP_SERVER setting
        echo "RTMP_SERVER=rtmps://hwosecurity.org:1936/live" >> /opt/streamlite/.env
    fi
    
    # Add HLS and DASH settings
    if ! grep -q "HLS_SERVER" "/opt/streamlite/.env"; then
        echo "HLS_SERVER=https://hwosecurity.org/hls" >> /opt/streamlite/.env
    fi
    
    if ! grep -q "DASH_SERVER" "/opt/streamlite/.env"; then
        echo "DASH_SERVER=https://hwosecurity.org/dash" >> /opt/streamlite/.env
    fi
    
    print_success "StreamLite configuration updated."
else
    print_error ".env file not found at /opt/streamlite/.env"
    print_info "You'll need to manually update your application settings."
fi

# Restart StreamLite application
print_info "Restarting StreamLite application..."
if systemctl is-active --quiet streamlite; then
    systemctl restart streamlite
    print_success "StreamLite application restarted."
else
    print_error "StreamLite service not found or not running."
    print_info "You'll need to restart your application manually."
fi

# Print summary
echo ""
echo -e "${BLUE}=== Setup Summary ===${NC}"
echo ""
print_success "RTMP streaming configured on rtmp://hwosecurity.org:1935/live"
print_success "RTMPS streaming configured on rtmps://hwosecurity.org:1936/live"
print_success "HLS streaming available at https://hwosecurity.org/hls"
print_success "DASH streaming available at https://hwosecurity.org/dash"
echo ""
print_info "Stream key authentication endpoint: http://localhost:5000/api/stream/authenticate"
print_info "Make sure to implement this endpoint in your StreamLite application."
echo ""
print_info "Example OBS Studio configuration:"
print_info "1. Go to Settings > Stream"
print_info "2. Service: Custom"
print_info "3. Server: rtmps://hwosecurity.org:1936/live"
print_info "4. Stream Key: [your-stream-key]"
echo ""
print_info "Example ffmpeg command for testing:"
print_info "ffmpeg -re -i test_video.mp4 -c:v libx264 -c:a aac -f flv rtmps://hwosecurity.org:1936/live/[your-stream-key]"
echo ""
print_info "To test your streaming setup, use a tool like VLC to open:"
print_info "https://hwosecurity.org/hls/[your-stream-key].m3u8"
echo ""
print_info "Troubleshooting:"
print_info "- Check Nginx logs: /var/log/nginx/error.log"
print_info "- Check stunnel logs: /var/log/stunnel4/stunnel.log"
print_info "- Ensure your firewall allows ports 80, 443, 1935, and 1936"
echo ""
print_info "Your streaming setup is now complete!"
echo ""