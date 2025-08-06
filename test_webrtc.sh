#!/bin/bash
# WebRTC testing script

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Banner
cat << "EOF"
 _    _     _     _____ _____ _____ 
| |  | |   | |   |  _  |_   _/  ___|
| |  | | __| |__ | | | | | | \ `--. 
| |/\| |/ /| '_ \| | | | | |  `--. \
\  /\  / /_| |_) \ \_/ /_| |_/\__/ /
 \/  \/\__/|_.__/ \___/ \___/\____/ 
                                    
EOF
echo "WebRTC Testing & Diagnostic Tool"
echo "================================="
echo ""

# Check if WebRTC port is open
print_header "Checking WebRTC Port"
WEBRTC_PORT=5443
if nc -z localhost $WEBRTC_PORT 2>/dev/null; then
    print_success "WebRTC port $WEBRTC_PORT is open and listening"
else
    print_error "WebRTC port $WEBRTC_PORT is not listening"
    
    # Check if service is running
    if systemctl is-active --quiet webrtc; then
        print_info "WebRTC service is running but not listening on port $WEBRTC_PORT"
    else
        print_error "WebRTC service is not running"
        print_info "Attempting to start WebRTC service..."
        systemctl start webrtc
        
        if systemctl is-active --quiet webrtc; then
            print_success "WebRTC service started successfully"
        else
            print_error "Failed to start WebRTC service"
        fi
    fi
fi

# Check if firewall is blocking WebRTC port
print_header "Checking Firewall Status"
if command -v ufw >/dev/null; then
    if ufw status | grep -q "$WEBRTC_PORT/tcp"; then
        print_success "Port $WEBRTC_PORT is allowed in UFW"
    else
        print_error "Port $WEBRTC_PORT is not allowed in UFW"
        print_info "Consider running sudo ufw allow $WEBRTC_PORT/tcp"
    fi
elif command -v firewall-cmd >/dev/null; then
    if firewall-cmd --list-ports | grep -q "$WEBRTC_PORT/tcp"; then
        print_success "Port $WEBRTC_PORT is allowed in FirewallD"
    else
        print_error "Port $WEBRTC_PORT is not allowed in FirewallD"
        print_info "Consider running sudo firewall-cmd --add-port=$WEBRTC_PORT/tcp --permanent && sudo firewall-cmd --reload"
    fi
elif command -v iptables >/dev/null; then
    if iptables -L -n | grep -q "tcp dpt:$WEBRTC_PORT"; then
        print_success "Port $WEBRTC_PORT is allowed in iptables"
    else
        print_error "Port $WEBRTC_PORT may not be allowed in iptables"
        print_info "Consider running sudo iptables -I INPUT -p tcp --dport $WEBRTC_PORT -j ACCEPT"
    fi
else
    print_info "No common firewall detected, unable to check firewall status"
    print_info "Ensure port $WEBRTC_PORT is open in your server's firewall"
fi

# Check SSL certificates for WebRTC
print_header "Checking SSL Certificates"
CERT_PATH=""
KEY_PATH=""

# Look for SSL certificate paths in common locations
for config in $(find /etc -type f -name "*.conf" 2>/dev/null | xargs grep -l "ssl_certificate" 2>/dev/null); do
    CERT_PATH=$(grep "ssl_certificate " $config | grep -v "_key" | head -1 | sed 's/.*ssl_certificate\s*\(.*\);.*/\1/')
    KEY_PATH=$(grep "ssl_certificate_key" $config | head -1 | sed 's/.*ssl_certificate_key\s*\(.*\);.*/\1/')
    
    if [ ! -z "$CERT_PATH" ] && [ ! -z "$KEY_PATH" ]; then
        break
    fi
done

if [ -z "$CERT_PATH" ] || [ -z "$KEY_PATH" ]; then
    print_error "Could not find SSL certificate paths in Nginx configs"
    print_info "WebRTC requires SSL certificates for secure connections"
else
    if [ -f "$CERT_PATH" ]; then
        print_success "SSL certificate exists: $CERT_PATH"
        # Check certificate expiration
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
        print_info "Certificate expires: $EXPIRY"
        
        # Check if certificate is expired
        if openssl x509 -checkend 0 -noout -in "$CERT_PATH"; then
            print_success "Certificate is still valid"
        else
            print_error "Certificate has expired!"
        fi
    else
        print_error "SSL certificate not found: $CERT_PATH"
    fi
    
    if [ -f "$KEY_PATH" ]; then
        print_success "SSL private key exists: $KEY_PATH"
    else
        print_error "SSL private key not found: $KEY_PATH"
    fi
fi

# Check WebRTC dependencies
print_header "Checking WebRTC Dependencies"
DEPS=("openssl" "python3" "python3-aiohttp" "python3-aiortc" "python3-socketio")

for dep in "${DEPS[@]}"; do
    if dpkg -l | grep -q "$dep"; then
        print_success "$dep is installed"
    else
        print_error "$dep is not installed"
        print_info "You may need to install this dependency with: sudo apt-get install $dep"
    fi
done

# Check SSL connection to WebRTC
print_header "Testing SSL Connection"
DOMAIN=$(hostname -f 2>/dev/null || hostname)
print_info "Testing SSL connection to $DOMAIN:$WEBRTC_PORT"

if openssl s_client -connect $DOMAIN:$WEBRTC_PORT < /dev/null 2>&1 | grep -q "CONNECTED"; then
    print_success "SSL connection to $DOMAIN:$WEBRTC_PORT successful"
else
    print_error "Could not establish SSL connection to $DOMAIN:$WEBRTC_PORT"
fi

# Summary
print_header "WebRTC Connection Information"
echo "To connect to WebRTC, users should access:"
echo "https://hwosecurity.org:5443/webrtc"
echo ""
echo "For broadcasters:"
echo "https://hwosecurity.org:5443/webrtc/broadcast"
echo ""
echo "For viewers:"
echo "https://hwosecurity.org:5443/webrtc/view"
echo ""

print_header "Next Steps"
echo "If you're experiencing issues with WebRTC streaming:"
echo "1. Check that port $WEBRTC_PORT is open and forwarded on your network/firewall"
echo "2. Ensure the WebRTC server is running (check logs with journalctl -u webrtc)"
echo "3. Verify SSL certificates are valid and properly configured"
echo "4. Test browser compatibility (WebRTC works best with Chrome, Firefox, or Edge)"
echo "5. Check your application logs for WebRTC specific errors"
echo ""

print_success "WebRTC diagnostics completed!"