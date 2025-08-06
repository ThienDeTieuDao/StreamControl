#!/bin/bash

# Streaming Diagnostic and Fix Script
# This script diagnoses and fixes issues with RTMP streaming

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    print_info "Try: sudo bash $0"
    exit 1
fi

print_header "RTMP Streaming Diagnostic Tool"
echo "This script will diagnose and fix issues with RTMP streaming."
echo ""

# Step 1: Check if Nginx is running
print_header "Checking Nginx Status"
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running"
    print_info "Attempting to start Nginx..."
    systemctl start nginx
    
    if systemctl is-active --quiet nginx; then
        print_success "Successfully started Nginx"
    else
        print_error "Failed to start Nginx. Check logs with: systemctl status nginx"
    fi
fi
echo ""

# Step 2: Check if Nginx has RTMP module
print_header "Checking RTMP Module"
if nginx -V 2>&1 | grep -q "nginx-rtmp-module" || grep -q "rtmp {" /etc/nginx/nginx.conf || find /etc/nginx -type f -name "*.conf" | xargs grep -l "rtmp {" >/dev/null; then
    print_success "RTMP module appears to be configured"
else
    print_error "RTMP module not found in Nginx configuration"
    print_info "You need to install nginx-rtmp-module or reconfigure Nginx with RTMP support"
    
    echo "Would you like to install the RTMP module now? (y/n):"
    read -r install_rtmp
    
    if [ "$install_rtmp" = "y" ]; then
        # Install RTMP module
        if command -v apt-get >/dev/null; then
            apt-get update
            apt-get install -y libnginx-mod-rtmp || apt-get install -y nginx-module-rtmp
        elif command -v yum >/dev/null; then
            yum install -y nginx-mod-rtmp
        else
            print_error "Unsupported package manager. Please install the RTMP module manually."
        fi
    fi
fi
echo ""

# Step 3: Check RTMP configuration
print_header "Checking RTMP Configuration"
rtmp_conf_found=0
rtmp_conf_path=""

# Check common locations for RTMP configuration
for conf_path in "/etc/nginx/nginx.conf" "/etc/nginx/conf.d/rtmp.conf" "/etc/nginx/modules-enabled/rtmp.conf" "/usr/local/nginx/conf/nginx.conf" "/www/server/panel/vhost/nginx/rtmp.conf"; do
    if [ -f "$conf_path" ] && grep -q "rtmp {" "$conf_path"; then
        rtmp_conf_found=1
        rtmp_conf_path="$conf_path"
        print_success "Found RTMP configuration in $conf_path"
        break
    fi
done

# Find RTMP config in any nginx conf file if not found in common locations
if [ "$rtmp_conf_found" -eq 0 ]; then
    # Find any config file with rtmp section
    rtmp_conf_path=$(find /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx -type f -name "*.conf" 2>/dev/null | xargs grep -l "rtmp {" | head -1)
    
    if [ -n "$rtmp_conf_path" ]; then
        rtmp_conf_found=1
        print_success "Found RTMP configuration in $rtmp_conf_path"
    else
        print_error "No RTMP configuration found"
        print_info "Creating a basic RTMP configuration..."
        
        # Determine where to create the config
        if [ -d "/etc/nginx/conf.d" ]; then
            rtmp_conf_path="/etc/nginx/conf.d/rtmp.conf"
        elif [ -d "/etc/nginx/modules-enabled" ]; then
            rtmp_conf_path="/etc/nginx/modules-enabled/rtmp.conf"
        else
            rtmp_conf_path="/etc/nginx/nginx.conf"
        fi
        
        # Create basic RTMP configuration
        if [ "$rtmp_conf_path" = "/etc/nginx/nginx.conf" ]; then
            # Append to main config file
            cat >> "$rtmp_conf_path" << EOF

# RTMP configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        # Live streaming
        application live {
            live on;
            record off;
            
            # HLS output
            hls on;
            hls_path /var/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # Allow streaming
            allow publish all;
            allow play all;
            
            # Authentication (enable this once basic streaming works)
            # on_publish http://localhost:5000/api/stream/auth;
        }
    }
}
EOF
        else
            # Create new config file
            cat > "$rtmp_conf_path" << EOF
# RTMP configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        # Live streaming
        application live {
            live on;
            record off;
            
            # HLS output
            hls on;
            hls_path /var/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # Allow streaming
            allow publish all;
            allow play all;
            
            # Authentication (enable this once basic streaming works)
            # on_publish http://localhost:5000/api/stream/auth;
        }
    }
}
EOF
        fi
        print_success "Created RTMP configuration at $rtmp_conf_path"
        rtmp_conf_found=1
    fi
fi

# Step 4: Check HLS directory
print_header "Checking HLS Directory"
hls_dir=$(grep -A 10 "hls on" "$rtmp_conf_path" | grep "hls_path" | head -1 | sed -E 's/.*hls_path\s+([^;]+);.*/\1/')

if [ -z "$hls_dir" ]; then
    print_error "Could not find HLS directory in configuration"
    print_info "Using default path /var/hls"
    hls_dir="/var/hls"
else
    print_success "Found HLS directory: $hls_dir"
fi

# Create HLS directory if it doesn't exist
if [ ! -d "$hls_dir" ]; then
    print_info "Creating HLS directory: $hls_dir"
    mkdir -p "$hls_dir"
    chmod -R 777 "$hls_dir"  # Very permissive for testing
else
    print_success "HLS directory exists"
    # Check permissions
    if [ ! -w "$hls_dir" ]; then
        print_error "HLS directory is not writable"
        print_info "Fixing permissions..."
        chmod -R 777 "$hls_dir"  # Very permissive for testing
    fi
fi
echo ""

# Step 5: Check HTTP/HTTPS configuration for HLS
print_header "Checking HTTP Configuration for HLS"
http_conf_found=0

# Find HTTP server block with HLS location
for conf_file in $(find /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx -type f -name "*.conf" 2>/dev/null); do
    if grep -q "location /hls" "$conf_file"; then
        http_conf_found=1
        print_success "Found HLS HTTP configuration in $conf_file"
        
        # Check alias path
        hls_http_path=$(grep -A 5 "location /hls" "$conf_file" | grep -E "alias|root" | head -1 | sed -E 's/.*\s+([^;]+);.*/\1/')
        
        if [ -n "$hls_http_path" ] && [ "$hls_http_path" != "$hls_dir" ]; then
            print_error "HLS HTTP path ($hls_http_path) does not match RTMP HLS path ($hls_dir)"
            print_info "Would you like to fix this? (y/n):"
            read -r fix_hls_path
            
            if [ "$fix_hls_path" = "y" ]; then
                # Backup config file
                cp "$conf_file" "$conf_file.bak"
                
                # Fix the path
                sed -i -E "s|(location /hls.*\n[^}]*)(alias|root)[[:space:]]+[^;]+;|\1\2 $hls_dir;|" "$conf_file"
                print_success "Updated HLS path in $conf_file"
            fi
        elif [ -n "$hls_http_path" ]; then
            print_success "HLS HTTP path matches RTMP HLS path"
        fi
        
        break
    fi
done

if [ "$http_conf_found" -eq 0 ]; then
    print_error "No HTTP configuration found for HLS"
    print_info "Adding HLS configuration to a server block..."
    
    # Find a server block to add HLS configuration
    server_block_file=$(find /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx -type f -name "*.conf" 2>/dev/null | xargs grep -l "server_name" | head -1)
    
    if [ -n "$server_block_file" ]; then
        # Backup config file
        cp "$server_block_file" "$server_block_file.bak"
        
        # Find a good place to insert the HLS location block
        if grep -q "location / {" "$server_block_file"; then
            # Insert before the root location
            sed -i '/location \/ {/i \
    # HLS streaming\
    location /hls {\
        alias '"$hls_dir"';\
        add_header Cache-Control no-cache;\
        add_header Access-Control-Allow-Origin *;\
        types {\
            application/vnd.apple.mpegurl m3u8;\
            video/mp2t ts;\
        }\
    }\
' "$server_block_file"
        else
            # Insert at the end of the server block
            sed -i '/server {/,/}/{s/}/    # HLS streaming\
    location \/hls {\
        alias '"$hls_dir"';\
        add_header Cache-Control no-cache;\
        add_header Access-Control-Allow-Origin *;\
        types {\
            application\/vnd.apple.mpegurl m3u8;\
            video\/mp2t ts;\
        }\
    }\
}/}' "$server_block_file"
        fi
        
        print_success "Added HLS configuration to $server_block_file"
        http_conf_found=1
    else
        print_error "Could not find a server block to add HLS configuration"
    fi
fi
echo ""

# Step 6: Check firewall
print_header "Checking Firewall"
if command -v ufw >/dev/null; then
    print_info "UFW firewall detected"
    
    if ufw status | grep -q "1935/tcp"; then
        print_success "Port 1935 (RTMP) is allowed in UFW"
    else
        print_error "Port 1935 (RTMP) is not allowed in UFW"
        print_info "Opening port 1935..."
        ufw allow 1935/tcp
        print_success "Port 1935 opened"
    fi
    
    if ufw status | grep -q "1936/tcp"; then
        print_success "Port 1936 (RTMPS) is allowed in UFW"
    else
        print_info "Opening port 1936 for RTMPS..."
        ufw allow 1936/tcp
        print_success "Port 1936 opened"
    fi
    
    if ufw status | grep -q "5443/tcp"; then
        print_success "Port 5443 (WebRTC) is allowed in UFW"
    else
        print_info "Opening port 5443 for WebRTC..."
        ufw allow 5443/tcp
        print_success "Port 5443 opened"
    fi
elif command -v firewall-cmd >/dev/null; then
    print_info "FirewallD detected"
    
    if firewall-cmd --list-ports | grep -q "1935/tcp"; then
        print_success "Port 1935 (RTMP) is allowed in FirewallD"
    else
        print_error "Port 1935 (RTMP) is not allowed in FirewallD"
        print_info "Opening port 1935..."
        firewall-cmd --add-port=1935/tcp --permanent
        firewall-cmd --reload
        print_success "Port 1935 opened"
    fi
    
    if firewall-cmd --list-ports | grep -q "1936/tcp"; then
        print_success "Port 1936 (RTMPS) is allowed in FirewallD"
    else
        print_info "Opening port 1936 for RTMPS..."
        firewall-cmd --add-port=1936/tcp --permanent
        firewall-cmd --reload
        print_success "Port 1936 opened"
    fi
    
    if firewall-cmd --list-ports | grep -q "5443/tcp"; then
        print_success "Port 5443 (WebRTC) is allowed in FirewallD"
    else
        print_info "Opening port 5443 for WebRTC..."
        firewall-cmd --add-port=5443/tcp --permanent
        firewall-cmd --reload
        print_success "Port 5443 opened"
    fi
elif command -v iptables >/dev/null; then
    print_info "iptables detected"
    
    if iptables -L -n | grep -q "tcp dpt:1935"; then
        print_success "Port 1935 (RTMP) is allowed in iptables"
    else
        print_error "Port 1935 (RTMP) is not allowed in iptables"
        print_info "Opening port 1935..."
        iptables -I INPUT -p tcp --dport 1935 -j ACCEPT
        # Try to make rule persistent if possible
        if command -v iptables-save >/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
        print_success "Port 1935 opened (note: may not persist after reboot depending on system configuration)"
    fi
    
    if iptables -L -n | grep -q "tcp dpt:1936"; then
        print_success "Port 1936 (RTMPS) is allowed in iptables"
    else
        print_info "Opening port 1936 for RTMPS..."
        iptables -I INPUT -p tcp --dport 1936 -j ACCEPT
        # Try to make rule persistent if possible
        if command -v iptables-save >/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
        print_success "Port 1936 opened (note: may not persist after reboot depending on system configuration)"
    fi
    
    if iptables -L -n | grep -q "tcp dpt:5443"; then
        print_success "Port 5443 (WebRTC) is allowed in iptables"
    else
        print_info "Opening port 5443 for WebRTC..."
        iptables -I INPUT -p tcp --dport 5443 -j ACCEPT
        # Try to make rule persistent if possible
        if command -v iptables-save >/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
        print_success "Port 5443 opened (note: may not persist after reboot depending on system configuration)"
    fi
elif [ -f "/etc/csf/csf.conf" ]; then
    print_info "ConfigServer Firewall (CSF) detected"
    
    if grep -q "^TCP_IN.*,1935," "/etc/csf/csf.conf" || grep -q "^TCP_IN.*,1935$" "/etc/csf/csf.conf"; then
        print_success "Port 1935 (RTMP) is allowed in CSF"
    else
        print_error "Port 1935 (RTMP) is not allowed in CSF"
        print_info "Opening port 1935..."
        # Backup the config file
        cp /etc/csf/csf.conf /etc/csf/csf.conf.bak
        # Add port to TCP_IN
        sed -i 's/^TCP_IN = "/TCP_IN = "1935,/' /etc/csf/csf.conf
        # Restart CSF
        csf -r
        print_success "Port 1935 opened in CSF"
    fi
    
    if grep -q "^TCP_IN.*,1936," "/etc/csf/csf.conf" || grep -q "^TCP_IN.*,1936$" "/etc/csf/csf.conf"; then
        print_success "Port 1936 (RTMPS) is allowed in CSF"
    else
        print_info "Opening port 1936 for RTMPS..."
        # Add port to TCP_IN
        sed -i 's/^TCP_IN = "/TCP_IN = "1936,/' /etc/csf/csf.conf
        # Restart CSF
        csf -r
        print_success "Port 1936 opened in CSF"
    fi
    
    if grep -q "^TCP_IN.*,5443," "/etc/csf/csf.conf" || grep -q "^TCP_IN.*,5443$" "/etc/csf/csf.conf"; then
        print_success "Port 5443 (WebRTC) is allowed in CSF"
    else
        print_info "Opening port 5443 for WebRTC..."
        # Add port to TCP_IN
        sed -i 's/^TCP_IN = "/TCP_IN = "5443,/' /etc/csf/csf.conf
        # Restart CSF
        csf -r
        print_success "Port 5443 opened in CSF"
    fi
else
    print_info "No common firewall detected. Make sure ports 1935, 1936, and 5443 are open."
    
    # Check if we're running on AWS EC2
    if curl -s http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        print_info "AWS EC2 instance detected. Remember to:"
        print_info "1. Check your Security Groups in the AWS Console"
        print_info "2. Add inbound rules for TCP ports 1935, 1936, and 5443"
    fi
    
    # Check if we're running on Google Cloud
    if curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/ >/dev/null 2>&1; then
        print_info "Google Cloud instance detected. Remember to:"
        print_info "1. Check your VPC Firewall Rules in the GCP Console"
        print_info "2. Add ingress rules for TCP ports 1935, 1936, and 5443"
    fi
fi
echo ""

# Step 7: Apply changes and test configuration
print_header "Applying Changes"
print_info "Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    print_success "Nginx configuration is valid"
    print_info "Restarting Nginx..."
    systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        print_success "Nginx restarted successfully"
    else
        print_error "Failed to restart Nginx"
    fi
else
    print_error "Nginx configuration test failed"
    print_info "Please check the error and fix the configuration"
fi
echo ""

# Step 8: Test RTMP connectivity locally
print_header "Testing RTMP Connectivity"
print_info "Checking if RTMP port is listening..."
if netstat -tuln | grep -q ":1935"; then
    print_success "RTMP port 1935 is listening"
else
    print_error "RTMP port 1935 is not listening"
    print_info "This suggests the Nginx RTMP module is not properly configured or not running"
fi

# Step 9: Create a test stream script
print_header "Creating Test Files"
mkdir -p /opt/streamlite/test
cd /opt/streamlite/test

# Create a tiny test video
print_info "Creating a test video file..."
if command -v ffmpeg >/dev/null; then
    ffmpeg -f lavfi -i testsrc=duration=10:size=640x480:rate=30 -c:v libx264 -b:v 800k test_video.mp4 -y
    print_success "Created test video: /opt/streamlite/test/test_video.mp4"
else
    print_error "ffmpeg not found. Cannot create test video."
    print_info "Installing ffmpeg..."
    apt-get update && apt-get install -y ffmpeg
    
    if command -v ffmpeg >/dev/null; then
        ffmpeg -f lavfi -i testsrc=duration=10:size=640x480:rate=30 -c:v libx264 -b:v 800k test_video.mp4 -y
        print_success "Created test video: /opt/streamlite/test/test_video.mp4"
    else
        print_error "Failed to install ffmpeg"
    fi
fi

# Create test streaming script
cat > /opt/streamlite/test/test_rtmp_stream.sh << 'EOF'
#!/bin/bash
# Test RTMP streaming script

# Get current server IP and public IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || curl -s http://ifconfig.me || curl -s https://ipinfo.io/ip)
DOMAIN="hwosecurity.org"
STREAM_KEY=${1:-"test_stream"}

# Choose which IP to use
echo "Choose streaming destination:"
echo "1) Domain: rtmp://$DOMAIN:1935/live/$STREAM_KEY"
echo "2) Public IP: rtmp://$PUBLIC_IP:1935/live/$STREAM_KEY"
echo "3) Private IP: rtmp://$PRIVATE_IP:1935/live/$STREAM_KEY"
read -p "Enter choice (1-3): " IP_CHOICE

case $IP_CHOICE in
    1) SERVER_IP=$DOMAIN ;;
    2) SERVER_IP=$PUBLIC_IP ;;
    3) SERVER_IP=$PRIVATE_IP ;;
    *) SERVER_IP=$DOMAIN ;;
esac

echo "Streaming test video to rtmp://$SERVER_IP:1935/live/$STREAM_KEY"
echo "Press Ctrl+C to stop streaming"

# Stream the test video in a loop
ffmpeg -re -stream_loop -1 -i test_video.mp4 -c:v copy -c:a copy -f flv rtmp://$SERVER_IP:1935/live/$STREAM_KEY
EOF

chmod +x /opt/streamlite/test/test_rtmp_stream.sh

print_success "Created test streaming script: /opt/streamlite/test/test_rtmp_stream.sh"

# Step 10: Summary and next steps
print_header "Summary and Next Steps"
echo "RTMP streaming setup has been checked and fixed where possible."
echo ""
print_info "To test streaming locally:"
echo "1. Run: cd /opt/streamlite/test && ./test_rtmp_stream.sh your_stream_key"
echo ""
print_info "To view the stream with VLC:"
echo "1. Open VLC"
echo "2. Press Ctrl+N"
echo "3. Enter URL: http://SERVER_IP/hls/your_stream_key.m3u8"
echo ""
print_info "If local streaming works but remote doesn't:"
echo "1. Check that your router has ports 1935, 1936, and 5443 forwarded to this server"
echo "2. Make sure your domain DNS record points to your public IP"
echo "3. Test if your server is reachable from outside your network"
echo ""
print_info "Troubleshooting commands:"
echo "- Check Nginx logs: tail -f /var/log/nginx/error.log"
echo "- Check if RTMP port is open: telnet hwosecurity.org 1935"
echo "- Check if WebRTC port is open: telnet hwosecurity.org 5443"
echo "- Test HTTP access to HLS: curl -I http://hwosecurity.org/hls"
echo ""

# Generate a curl command to test HLS HTTP access
SERVER_NAME=$(grep "server_name" $(find /etc/nginx -type f -name "*.conf" | xargs grep -l "server_name") | head -1 | sed -E 's/.*server_name\s+([^;]+);.*/\1/' | awk '{print $1}')
print_info "To test HLS HTTP access, run:"
echo "curl -I http://$SERVER_NAME/hls"
echo ""

print_success "Streaming diagnostics and fixes completed!"