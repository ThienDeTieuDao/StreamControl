#!/bin/bash
# SSL Troubleshooting and Fix Script for hwosecurity.org

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}       SSL Configuration for hwosecurity.org      ${NC}"
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

# Detect web server
if command -v nginx &> /dev/null; then
    WEB_SERVER="nginx"
    print_info "Detected web server: Nginx"
elif command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
    WEB_SERVER="apache"
    print_info "Detected web server: Apache"
else
    print_error "No supported web server detected. Please install Nginx or Apache."
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

# Check for certbot
if ! command -v certbot &> /dev/null; then
    print_info "Certbot not found. Installing..."
    
    if [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y certbot
        
        if [ "$WEB_SERVER" = "nginx" ]; then
            apt-get install -y python3-certbot-nginx
        elif [ "$WEB_SERVER" = "apache" ]; then
            apt-get install -y python3-certbot-apache
        fi
    elif [ "$OS" = "redhat" ]; then
        # Install EPEL repository if needed
        if ! rpm -q epel-release &> /dev/null; then
            yum install -y epel-release
        fi
        
        yum install -y certbot
        
        if [ "$WEB_SERVER" = "nginx" ]; then
            yum install -y python3-certbot-nginx
        elif [ "$WEB_SERVER" = "apache" ]; then
            yum install -y python3-certbot-apache
        fi
    else
        print_error "Unable to install Certbot automatically. Please install it manually."
        exit 1
    fi
    
    if command -v certbot &> /dev/null; then
        print_success "Certbot installed successfully"
    else
        print_error "Failed to install Certbot. Please install it manually."
        exit 1
    fi
else
    print_success "Certbot is already installed"
fi

# Check if domain points to current server
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short hwosecurity.org)

print_info "Server IP: $SERVER_IP"
print_info "Domain IP: $DOMAIN_IP"

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    print_error "Warning: Domain hwosecurity.org doesn't seem to point to this server."
    print_info "Certbot typically requires the domain to point to this server for verification."
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Please update your DNS records to point hwosecurity.org to $SERVER_IP and try again."
        exit 1
    fi
fi

# Check port 80 and 443 availability
print_info "Checking if ports 80 and 443 are available..."

PORT_80_STATUS=$(netstat -tuln | grep ":80 " | wc -l)
PORT_443_STATUS=$(netstat -tuln | grep ":443 " | wc -l)

if [ "$PORT_80_STATUS" -gt 0 ]; then
    print_info "Port 80 is being used. This is expected if your web server is running."
else
    print_error "Port 80 is not in use. Your web server may not be running."
fi

if [ "$PORT_443_STATUS" -gt 0 ]; then
    print_info "Port 443 is being used. This is expected if SSL is already configured."
else
    print_info "Port 443 is not in use. This is normal if SSL is not yet configured."
fi

# Try to obtain SSL certificate
print_info "Attempting to obtain SSL certificate for hwosecurity.org..."

if [ "$WEB_SERVER" = "nginx" ]; then
    # Nginx-specific preparation
    # Ensure site is enabled
    if [ -f /etc/nginx/sites-available/hwosecurity.org ]; then
        if [ ! -f /etc/nginx/sites-enabled/hwosecurity.org ]; then
            print_info "Enabling the site in Nginx..."
            ln -sf /etc/nginx/sites-available/hwosecurity.org /etc/nginx/sites-enabled/
            systemctl reload nginx
        fi
    fi
    
    # Try with nginx plugin first
    certbot --nginx -d hwosecurity.org -d www.hwosecurity.org --non-interactive --agree-tos --register-unsafely-without-email
    
    if [ $? -ne 0 ]; then
        print_info "Nginx plugin method failed. Trying standalone method..."
        # Stop nginx temporarily
        systemctl stop nginx
        
        # Try standalone method
        certbot certonly --standalone -d hwosecurity.org -d www.hwosecurity.org --non-interactive --agree-tos --register-unsafely-without-email
        
        # Start nginx again
        systemctl start nginx
    fi
elif [ "$WEB_SERVER" = "apache" ]; then
    # Apache-specific preparation
    # Try with apache plugin first
    certbot --apache -d hwosecurity.org -d www.hwosecurity.org --non-interactive --agree-tos --register-unsafely-without-email
    
    if [ $? -ne 0 ]; then
        print_info "Apache plugin method failed. Trying standalone method..."
        # Stop apache temporarily
        if [ "$OS" = "debian" ]; then
            systemctl stop apache2
        else
            systemctl stop httpd
        fi
        
        # Try standalone method
        certbot certonly --standalone -d hwosecurity.org -d www.hwosecurity.org --non-interactive --agree-tos --register-unsafely-without-email
        
        # Start apache again
        if [ "$OS" = "debian" ]; then
            systemctl start apache2
        else
            systemctl start httpd
        fi
    fi
fi

# Check if certificate was obtained
if [ -d "/etc/letsencrypt/live/hwosecurity.org" ]; then
    print_success "SSL certificate obtained successfully!"
    
    # Check certificate expiration
    EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/hwosecurity.org/cert.pem | cut -d= -f2)
    print_info "Certificate is valid until: $EXPIRY"
    
    # Set up auto-renewal
    print_info "Setting up automatic renewal cron job..."
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | sort | uniq | crontab -
    print_success "Automatic renewal configured"
    
    # Test renewal
    print_info "Testing certificate renewal process..."
    certbot renew --dry-run
    
    # Reload web server to apply changes
    if [ "$WEB_SERVER" = "nginx" ]; then
        systemctl reload nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        if [ "$OS" = "debian" ]; then
            systemctl reload apache2
        else
            systemctl reload httpd
        fi
    fi
    
    print_success "SSL setup completed successfully!"
    print_info "Your site should now be accessible at https://hwosecurity.org"
else
    print_error "Failed to obtain SSL certificate."
    print_info "Let's try the manual DNS challenge method instead..."
    
    # Try DNS challenge method
    print_info "Starting DNS challenge method..."
    certbot certonly --manual --preferred-challenges dns -d hwosecurity.org -d www.hwosecurity.org
    
    if [ -d "/etc/letsencrypt/live/hwosecurity.org" ]; then
        print_success "SSL certificate obtained successfully with manual method!"
        
        print_info "Setting up automatic renewal cron job..."
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | sort | uniq | crontab -
        
        print_info "Please remember that manual DNS verification may require you to update DNS records for renewals."
    else
        print_error "All automated methods failed. Here are some alternative options:"
        print_info "1. Use a commercial SSL certificate"
        print_info "2. Use Cloudflare for DNS and SSL"
        print_info "3. Try the Manual DNS verification again when you can update DNS records"
        print_info "4. Check for firewall issues blocking HTTP/HTTPS traffic"
    fi
fi

# Provide additional information
echo ""
echo -e "${BLUE}=== Additional Information ===${NC}"
echo ""
print_info "SSL Certificate location: /etc/letsencrypt/live/hwosecurity.org/"
print_info "Certificate Files:"
print_info "- fullchain.pem: Full certificate chain"
print_info "- privkey.pem: Private key"

if [ "$WEB_SERVER" = "nginx" ]; then
    cat << EOF

Configuration example for Nginx:

server {
    listen 80;
    server_name hwosecurity.org www.hwosecurity.org;
    
    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name hwosecurity.org www.hwosecurity.org;
    
    # SSL parameters
    ssl_certificate /etc/letsencrypt/live/hwosecurity.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hwosecurity.org/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Rest of your server configuration...
}
EOF
elif [ "$WEB_SERVER" = "apache" ]; then
    cat << EOF

Configuration example for Apache:

<VirtualHost *:80>
    ServerName hwosecurity.org
    ServerAlias www.hwosecurity.org
    Redirect permanent / https://hwosecurity.org/
</VirtualHost>

<VirtualHost *:443>
    ServerName hwosecurity.org
    ServerAlias www.hwosecurity.org
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/hwosecurity.org/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/hwosecurity.org/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/hwosecurity.org/chain.pem
    
    # Rest of your server configuration...
</VirtualHost>
EOF
fi

echo ""
print_info "To test your SSL configuration, visit: https://www.ssllabs.com/ssltest/analyze.html?d=hwosecurity.org"
echo ""