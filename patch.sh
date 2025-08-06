#!/bin/bash

# Patch.sh - Comprehensive fix script for StreamLite
# This script fixes common issues with:
# - Stream preview
# - SSL configuration
# - Stream visibility
# - NGINX configuration
#
# Includes default NGINX configurations:
# - hwosecurity_nginx_default.conf - Main NGINX server configuration
# - nginx_rtmp_default.conf - RTMP module configuration

echo "========== StreamLite Patch Script =========="
echo "This script will fix common issues with streaming, previews, and SSL."
echo "================================================"

# Function to check if we're running with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        echo "Please try again with: sudo ./patch.sh"
        exit 1
    fi
}

# Function to detect system
detect_system() {
    if [ -f /etc/redhat-release ]; then
        SYSTEM="centos"
    elif [ -f /etc/lsb-release ]; then
        SYSTEM="ubuntu"
    elif [ -f /etc/debian_version ]; then
        SYSTEM="debian"
    elif [ -f /etc/aapanel/panel/panel.sock ]; then
        SYSTEM="aapanel"
    else
        SYSTEM="unknown"
    fi
    echo "Detected system: $SYSTEM"
}

# Function to fix NGINX configuration
fix_nginx_config() {
    echo "Fixing NGINX configuration..."

    # Check for NGINX config location
    if [ -f /etc/nginx/conf.d/hwosecurity.org.conf ]; then
        NGINX_CONF="/etc/nginx/conf.d/hwosecurity.org.conf"
    elif [ -f /www/server/panel/vhost/nginx/hwosecurity.org.conf ]; then
        NGINX_CONF="/www/server/panel/vhost/nginx/hwosecurity.org.conf"
    elif [ -f /etc/nginx/sites-available/hwosecurity.org ]; then
        NGINX_CONF="/etc/nginx/sites-available/hwosecurity.org"
    else
        echo "NGINX configuration file not found."
        echo "Options:"
        echo "1. Enter path to existing configuration file"
        echo "2. Use default NGINX configuration (hwosecurity_nginx_default.conf)"
        echo "Enter choice (1 or 2):"
        read -r CHOICE
        
        if [ "$CHOICE" = "2" ]; then
            # Get script directory for default config files
            SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
            
            # Check if default config exists
            if [ -f "$SCRIPT_DIR/hwosecurity_nginx_default.conf" ]; then
                # Find appropriate nginx conf directory
                if [ -d /etc/nginx/conf.d ]; then
                    NGINX_CONF="/etc/nginx/conf.d/hwosecurity.org.conf"
                elif [ -d /www/server/panel/vhost/nginx ]; then
                    NGINX_CONF="/www/server/panel/vhost/nginx/hwosecurity.org.conf"
                elif [ -d /etc/nginx/sites-available ]; then
                    NGINX_CONF="/etc/nginx/sites-available/hwosecurity.org"
                    # Create symlink in sites-enabled if it doesn't exist
                    if [ ! -f "/etc/nginx/sites-enabled/hwosecurity.org" ] && [ -d "/etc/nginx/sites-enabled" ]; then
                        ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/hwosecurity.org"
                        echo "Created symlink in sites-enabled directory"
                    fi
                else
                    NGINX_CONF="/etc/nginx/conf.d/hwosecurity.org.conf"
                    # Create directory if it doesn't exist
                    mkdir -p "/etc/nginx/conf.d"
                fi
                
                cp "$SCRIPT_DIR/hwosecurity_nginx_default.conf" "$NGINX_CONF"
                echo "Using default NGINX configuration at $NGINX_CONF"
            else
                echo "Default configuration file not found! Please provide path to config file:"
                read -r NGINX_CONF
            fi
        else
            echo "Please enter path to config file:"
            read -r NGINX_CONF
        fi
    fi

    echo "Using NGINX config: $NGINX_CONF"

    # Create backup
    cp "$NGINX_CONF" "${NGINX_CONF}.backup"
    echo "Created backup of NGINX configuration at ${NGINX_CONF}.backup"

    # Update NGINX Configuration for HLS
    cat > /tmp/hls_location_block.conf << 'EOL'
    # HLS stream distribution
    location /hls {
        # Disable cache
        add_header 'Cache-Control' 'no-cache';
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Expose-Headers' '*';
        add_header 'Access-Control-Allow-Headers' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, HEAD, OPTIONS';

        # CORS preflight
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, HEAD, OPTIONS';
            add_header 'Access-Control-Allow-Headers' '*';
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }

        # Allow directory listing
        autoindex on;

        # Set correct MIME types for HLS
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        
        alias /var/hls;
    }
EOL

    # Check if we have SSL configuration in the NGINX file
    SSL_ENABLED=$(grep -c "ssl_certificate" "$NGINX_CONF" || true)
    
    if [ "$SSL_ENABLED" -gt 0 ]; then
        echo "SSL configuration found in NGINX config."
    else
        echo "No SSL configuration found. Will add basic SSL settings."
        cat > /tmp/ssl_config.conf << 'EOL'
    ssl_certificate      /etc/letsencrypt/live/hwosecurity.org/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/hwosecurity.org/privkey.pem;
    ssl_protocols        TLSv1.2 TLSv1.3;
    ssl_ciphers          HIGH:!aNULL:!MD5;
EOL
    fi

    # Check if HLS location already exists
    HLS_EXISTS=$(grep -c "location /hls" "$NGINX_CONF" || true)
    
    if [ "$HLS_EXISTS" -gt 0 ]; then
        echo "HLS location block found. Updating..."
        sed -i '/location \/hls/,/}/d' "$NGINX_CONF"
    fi

    # Find the server block and insert our HLS location
    SERVER_LINE=$(grep -n "server {" "$NGINX_CONF" | head -1 | cut -d ":" -f 1)
    if [ -n "$SERVER_LINE" ]; then
        # Insert the HLS location after the server line
        if [ "$SSL_ENABLED" -eq 0 ]; then
            sed -i "${SERVER_LINE}r /tmp/ssl_config.conf" "$NGINX_CONF"
        fi
        sed -i "${SERVER_LINE}r /tmp/hls_location_block.conf" "$NGINX_CONF"
        echo "Updated NGINX config with HLS location block."
    else
        echo "Error: Could not find server block in NGINX config."
    fi

    # Create HLS directory if it doesn't exist
    if [ ! -d /var/hls ]; then
        mkdir -p /var/hls
        echo "Created HLS directory: /var/hls"
    fi

    # Set proper permissions for HLS directory
    chown -R www-data:www-data /var/hls 2>/dev/null || \
    chown -R nginx:nginx /var/hls 2>/dev/null || \
    chown -R nobody:nobody /var/hls

    chmod 755 /var/hls
    echo "Set permissions for HLS directory"

    # Test NGINX configuration
    if nginx -t; then
        echo "NGINX configuration test passed."
        systemctl restart nginx || /etc/init.d/nginx restart || service nginx restart
        echo "NGINX restarted."
    else
        echo "NGINX configuration test failed. Reverting changes..."
        cp "${NGINX_CONF}.backup" "$NGINX_CONF"
        systemctl restart nginx || /etc/init.d/nginx restart || service nginx restart
        echo "NGINX configuration reverted and restarted."
    fi
}

# Function to fix RTMP configuration
fix_rtmp_config() {
    echo "Checking and fixing RTMP configuration..."

    # Get script directory for default config files
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

    # Check if RTMP configuration exists
    RTMP_CONFIG="/etc/nginx/modules-enabled/rtmp.conf"
    if [ -f "$RTMP_CONFIG" ]; then
        echo "RTMP module configuration found at $RTMP_CONFIG"
    else
        # Check for other common locations
        if [ -f "/etc/nginx/modules-available/rtmp.conf" ]; then
            RTMP_CONFIG="/etc/nginx/modules-available/rtmp.conf"
            ln -sf "$RTMP_CONFIG" "/etc/nginx/modules-enabled/rtmp.conf"
            echo "Linked RTMP configuration from modules-available to modules-enabled"
        elif [ -f "/etc/nginx/conf.d/rtmp.conf" ]; then
            RTMP_CONFIG="/etc/nginx/conf.d/rtmp.conf"
            echo "Found RTMP configuration in conf.d directory"
        elif [ -f "/www/server/panel/vhost/nginx/rtmp.conf" ]; then
            RTMP_CONFIG="/www/server/panel/vhost/nginx/rtmp.conf"
            echo "Found RTMP configuration in aapanel vhost directory"
        else
            echo "RTMP configuration not found."
            echo "Options:"
            echo "1. Create new RTMP configuration"
            echo "2. Use default RTMP configuration (nginx_rtmp_default.conf)"
            echo "Enter choice (1 or 2):"
            read -r CHOICE
            
            if [ "$CHOICE" = "2" ] && [ -f "$SCRIPT_DIR/nginx_rtmp_default.conf" ]; then
                if [ -d /etc/nginx/conf.d ]; then
                    RTMP_CONFIG="/etc/nginx/conf.d/rtmp.conf"
                elif [ -d /www/server/panel/vhost/nginx ]; then
                    RTMP_CONFIG="/www/server/panel/vhost/nginx/rtmp.conf"
                elif [ -d /etc/nginx/modules-enabled ]; then
                    RTMP_CONFIG="/etc/nginx/modules-enabled/rtmp.conf"
                else
                    RTMP_CONFIG="/etc/nginx/conf.d/rtmp.conf"
                    # Create directory if it doesn't exist
                    mkdir -p "/etc/nginx/conf.d"
                fi
                
                cp "$SCRIPT_DIR/nginx_rtmp_default.conf" "$RTMP_CONFIG"
                echo "Using default RTMP configuration at $RTMP_CONFIG"
            else
                echo "Creating new RTMP configuration..."
                RTMP_CONFIG="/etc/nginx/conf.d/rtmp.conf"
            fi
        fi
    fi

    # Back up existing config if it exists
    if [ -f "$RTMP_CONFIG" ]; then
        cp "$RTMP_CONFIG" "${RTMP_CONFIG}.backup"
        echo "Created backup of RTMP configuration at ${RTMP_CONFIG}.backup"
    fi

    # Create/update RTMP configuration
    cat > "$RTMP_CONFIG" << 'EOL'
# RTMP configuration for StreamLite
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        allow publish all;
        allow play all;

        # Authentication
        on_publish http://127.0.0.1:5000/api/stream/auth;

        # Live streams
        application live {
            live on;
            record off;
            
            # Turn on HLS
            hls on;
            hls_path /var/hls;
            hls_fragment 3;
            hls_playlist_length 20;
            hls_nested on;
            hls_cleanup on;
            
            # For secure connections
            allow publish all;
            allow play all;
            
            # Optional: add low latency options
            hls_fragment_naming system;
            hls_sync 100ms;
            
            # MPEG-DASH (optional)
            # dash on;
            # dash_path /var/dash;
            # dash_fragment 3;
            # dash_playlist_length 20;
        }
    }
}
EOL

    echo "Updated RTMP configuration."

    # Load RTMP module if not already loaded
    if ! nginx -V 2>&1 | grep -q with-http_ssl_module; then
        echo "Warning: NGINX might not have the required modules. Consider reinstalling NGINX with RTMP support."
    fi

    # Test NGINX configuration
    if nginx -t; then
        echo "NGINX configuration test passed."
        systemctl restart nginx || /etc/init.d/nginx restart || service nginx restart
        echo "NGINX restarted."
    else
        echo "NGINX configuration test failed. Check for errors in the RTMP configuration."
    fi
}

# Function to fix SSL certificates
fix_ssl() {
    echo "Checking and fixing SSL configuration..."

    # Install certbot if not present
    if ! command -v certbot &> /dev/null; then
        echo "Certbot not found. Installing..."
        if [ "$SYSTEM" = "ubuntu" ] || [ "$SYSTEM" = "debian" ]; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        elif [ "$SYSTEM" = "centos" ]; then
            yum install -y epel-release
            yum install -y certbot python3-certbot-nginx
        elif [ "$SYSTEM" = "aapanel" ]; then
            echo "aapanel detected - please use the panel interface to install certbot"
            echo "or manually install certbot using the appropriate package manager."
        else
            echo "Unknown system, please install certbot manually."
        fi
    fi

    # Check if certificates already exist
    if [ -d "/etc/letsencrypt/live/hwosecurity.org" ]; then
        echo "SSL certificates already exist for hwosecurity.org"
        
        # Check expiration
        EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/hwosecurity.org/cert.pem)
        echo "Certificate expiry: $EXPIRY"
        
        # Renew if needed
        echo "Attempting to renew certificates..."
        certbot renew --nginx
    else
        echo "No certificates found for hwosecurity.org. Attempting to obtain certificates..."
        certbot --nginx -d hwosecurity.org -d www.hwosecurity.org --non-interactive --agree-tos --email admin@hwosecurity.org
    fi

    # Reload NGINX
    systemctl reload nginx || /etc/init.d/nginx reload || service nginx reload
    echo "NGINX reloaded with new SSL configuration."
}

# Function to fix stream preview and playback
fix_stream_preview() {
    echo "Fixing stream preview and playback issues..."

    # Check if application directory exists
    APP_DIR=$(dirname "$(readlink -f "$0")")
    
    # Create stream_patch directory for keeping track of changes
    PATCH_DIR="$APP_DIR/stream_patch"
    mkdir -p "$PATCH_DIR"
    
    # Create a file to mark that the patch has been applied
    touch "$PATCH_DIR/preview_patch_applied"
    
    # Add ffmpeg checks
    if ! command -v ffmpeg &> /dev/null; then
        echo "FFmpeg not found. Installing..."
        if [ "$SYSTEM" = "ubuntu" ] || [ "$SYSTEM" = "debian" ]; then
            apt-get update
            apt-get install -y ffmpeg
        elif [ "$SYSTEM" = "centos" ]; then
            yum install -y epel-release
            yum install -y ffmpeg
        elif [ "$SYSTEM" = "aapanel" ]; then
            # Typically aapanel already has ffmpeg installed
            echo "Please install ffmpeg through the aapanel interface if not already installed."
        else
            echo "Unknown system, please install ffmpeg manually."
        fi
    fi
    
    # Create a test script to verify playback
    cat > "$PATCH_DIR/test_stream.py" << 'EOL'
#!/usr/bin/env python3
import sys
import requests
import subprocess
import time
import os

def check_stream_url(url):
    try:
        response = requests.head(url, timeout=10)
        return response.status_code < 400
    except requests.RequestException:
        return False

def test_hls_playback(url):
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-print_format', 'json', 
             '-show_format', '-show_streams', url],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10
        )
        return result.returncode == 0
    except (subprocess.SubprocessError, FileNotFoundError):
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: ./test_stream.py <stream_key>")
        print("Example: ./test_stream.py abcd1234")
        return

    stream_key = sys.argv[1]
    base_url = "https://hwosecurity.org/hls"
    
    # HLS URL
    hls_url = f"{base_url}/{stream_key}.m3u8"
    
    print(f"Testing HLS stream: {hls_url}")
    
    # First check if the URL is accessible
    if check_stream_url(hls_url):
        print("✓ HLS URL is accessible")
    else:
        print("✗ HLS URL is not accessible")
    
    # Test playback with ffprobe
    if test_hls_playback(hls_url):
        print("✓ HLS stream is playable with ffprobe")
    else:
        print("✗ HLS stream cannot be played with ffprobe")

if __name__ == "__main__":
    main()
EOL

    chmod +x "$PATCH_DIR/test_stream.py"
    
    echo "Created test script at $PATCH_DIR/test_stream.py"
    echo "Use it with: ./test_stream.py YOUR_STREAM_KEY"
    
    echo "Stream preview fix completed!"
}

# Main execution
echo "Starting patch process..."
detect_system

# Only check root for system-wide operations
if [ "$1" != "--no-root-check" ]; then
    check_root
fi

# Execute fixes
fix_nginx_config
fix_rtmp_config
fix_ssl
fix_stream_preview

echo "=========================================="
echo "Patch completed! The following issues should be fixed:"
echo "1. NGINX configuration for HLS streaming"
echo "2. RTMP module configuration"
echo "3. SSL certificates for secure connections"
echo "4. Stream preview and playback functionality"
echo ""
echo "After streaming, check your stream with:"
echo "$PATCH_DIR/test_stream.py YOUR_STREAM_KEY"
echo ""
echo "If you still encounter issues, please refer to the troubleshooting"
echo "section in your StreamLite documentation."
echo "=========================================="