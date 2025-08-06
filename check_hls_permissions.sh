#!/bin/bash

# Check HLS Directory Permissions Script
# This script checks and fixes permissions for the HLS directory used by the RTMP module

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

print_header "HLS Directory Permissions Checker"
echo "This script will check and fix permissions for the HLS directory used by RTMP streaming."
echo ""

# Find RTMP configuration and HLS path
print_header "Finding HLS Directory"

# Try to find the HLS path from nginx configuration
HLS_DIR=""
NGINX_CONF_FILES=""

# Check for nginx-rtmp configuration files
for conf_path in "/etc/nginx/nginx.conf" "/etc/nginx/conf.d/rtmp.conf" "/etc/nginx/modules-enabled/rtmp.conf" "/usr/local/nginx/conf/nginx.conf" "/www/server/panel/vhost/nginx/rtmp.conf"; do
    if [ -f "$conf_path" ] && grep -q "hls_path" "$conf_path"; then
        NGINX_CONF_FILES="$NGINX_CONF_FILES $conf_path"
        HLS_PATH=$(grep -A 10 "hls on" "$conf_path" | grep "hls_path" | head -1 | sed -E 's/.*hls_path\s+([^;]+);.*/\1/')
        if [ -n "$HLS_PATH" ]; then
            HLS_DIR="$HLS_PATH"
            print_success "Found HLS directory in $conf_path: $HLS_DIR"
            break
        fi
    fi
done

# If not found in common locations, search all nginx conf files
if [ -z "$HLS_DIR" ]; then
    print_info "Searching all nginx configuration files for HLS path..."
    CONF_FILE=$(find /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx -type f -name "*.conf" 2>/dev/null | xargs grep -l "hls_path" | head -1)
    
    if [ -n "$CONF_FILE" ]; then
        HLS_PATH=$(grep -A 10 "hls on" "$CONF_FILE" | grep "hls_path" | head -1 | sed -E 's/.*hls_path\s+([^;]+);.*/\1/')
        if [ -n "$HLS_PATH" ]; then
            HLS_DIR="$HLS_PATH"
            print_success "Found HLS directory in $CONF_FILE: $HLS_DIR"
        fi
    fi
fi

# If still not found, use default locations
if [ -z "$HLS_DIR" ]; then
    print_error "Could not find HLS directory in nginx configuration"
    print_info "Checking common HLS directory locations..."
    
    for dir in "/var/hls" "/var/www/hls" "/usr/local/nginx/html/hls" "/www/wwwroot/default/hls"; do
        if [ -d "$dir" ]; then
            HLS_DIR="$dir"
            print_success "Found existing HLS directory: $HLS_DIR"
            break
        fi
    done
    
    # If still not found, use default
    if [ -z "$HLS_DIR" ]; then
        HLS_DIR="/var/hls"
        print_info "Using default HLS directory: $HLS_DIR"
    fi
fi

# Check if HLS directory exists
print_header "Checking HLS Directory"

if [ ! -d "$HLS_DIR" ]; then
    print_error "HLS directory does not exist: $HLS_DIR"
    print_info "Creating directory..."
    mkdir -p "$HLS_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "Created HLS directory: $HLS_DIR"
    else
        print_error "Failed to create HLS directory"
        exit 1
    fi
else
    print_success "HLS directory exists: $HLS_DIR"
fi

# Find nginx user
print_header "Finding Nginx User"

NGINX_USER=""

# Try to get nginx user from configuration
for conf_file in $(find /etc/nginx /usr/local/nginx/conf -type f -name "*.conf" 2>/dev/null); do
    if grep -q "^user" "$conf_file"; then
        NGINX_USER=$(grep "^user" "$conf_file" | head -1 | awk '{print $2}' | sed 's/;$//')
        print_success "Found nginx user in $conf_file: $NGINX_USER"
        break
    fi
done

# If not found in configuration, try to get from process
if [ -z "$NGINX_USER" ]; then
    if ps aux | grep -v grep | grep -q nginx; then
        NGINX_USER=$(ps aux | grep -v grep | grep "nginx: master" | awk '{print $1}' | head -1)
        print_success "Found nginx user from process: $NGINX_USER"
    fi
fi

# If still not found, use common defaults
if [ -z "$NGINX_USER" ]; then
    print_error "Could not determine nginx user"
    print_info "Checking common nginx users..."
    
    for user in "www-data" "nginx" "nobody" "apache" "httpd" "www"; do
        if id -u "$user" >/dev/null 2>&1; then
            NGINX_USER="$user"
            print_success "Using common nginx user: $NGINX_USER"
            break
        fi
    done
    
    # If still not found, use nobody
    if [ -z "$NGINX_USER" ]; then
        NGINX_USER="nobody"
        print_info "Using default user: $NGINX_USER"
    fi
fi

# Check and fix directory permissions
print_header "Checking Directory Permissions"

# Get current permissions
CURRENT_PERMS=$(stat -c "%a" "$HLS_DIR" 2>/dev/null || stat -f "%p" "$HLS_DIR" 2>/dev/null | cut -c 3-5)
CURRENT_OWNER=$(stat -c "%U" "$HLS_DIR" 2>/dev/null || stat -f "%Su" "$HLS_DIR" 2>/dev/null)
CURRENT_GROUP=$(stat -c "%G" "$HLS_DIR" 2>/dev/null || stat -f "%Sg" "$HLS_DIR" 2>/dev/null)

print_info "Current permissions: $CURRENT_PERMS ($CURRENT_OWNER:$CURRENT_GROUP)"

# Check if directory is writable by nginx
if sudo -u "$NGINX_USER" test -w "$HLS_DIR" 2>/dev/null; then
    print_success "Directory is writable by nginx user ($NGINX_USER)"
else
    print_error "Directory is not writable by nginx user ($NGINX_USER)"
    print_info "Fixing permissions..."
    
    # Change ownership to nginx user
    chown -R "$NGINX_USER":"$NGINX_USER" "$HLS_DIR"
    
    # Set permissions to 755 (or more permissive for troubleshooting)
    chmod -R 755 "$HLS_DIR"
    
    # Check if the fix worked
    if sudo -u "$NGINX_USER" test -w "$HLS_DIR" 2>/dev/null; then
        print_success "Successfully fixed permissions"
        print_info "New permissions: $(stat -c "%a" "$HLS_DIR" 2>/dev/null || stat -f "%p" "$HLS_DIR" 2>/dev/null | cut -c 3-5) ($(stat -c "%U" "$HLS_DIR" 2>/dev/null || stat -f "%Su" "$HLS_DIR" 2>/dev/null):$(stat -c "%G" "$HLS_DIR" 2>/dev/null || stat -f "%Sg" "$HLS_DIR" 2>/dev/null))"
    else
        print_error "Failed to fix permissions"
        print_info "Setting more permissive permissions for troubleshooting..."
        chmod -R 777 "$HLS_DIR"
        print_info "Set permissions to 777 for testing purposes"
        print_warning "This is not recommended for production"
    fi
fi

# Check if SELinux is present and affecting permissions
print_header "Checking SELinux Context"

if command -v getenforce >/dev/null 2>&1; then
    SELINUX_STATUS=$(getenforce)
    print_info "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        print_info "Checking SELinux context for $HLS_DIR"
        
        if command -v ls >/dev/null 2>&1 && ls -Z "$HLS_DIR" >/dev/null 2>&1; then
            SELINUX_CONTEXT=$(ls -Z "$HLS_DIR" | head -1 | awk '{print $4}')
            print_info "Current SELinux context: $SELINUX_CONTEXT"
            
            print_info "Setting appropriate SELinux context for web content..."
            if command -v chcon >/dev/null 2>&1; then
                chcon -R -t httpd_sys_content_t "$HLS_DIR" 2>/dev/null
                chcon -R -t httpd_sys_rw_content_t "$HLS_DIR" 2>/dev/null
                print_success "Applied httpd_sys_content_t and httpd_sys_rw_content_t contexts"
            fi
        fi
    fi
fi

# Create test file to verify write permissions
print_header "Testing Write Permissions"

TEST_FILE="$HLS_DIR/permission_test_$(date +%s).txt"
if sudo -u "$NGINX_USER" touch "$TEST_FILE" 2>/dev/null; then
    print_success "Successfully created test file as nginx user"
    sudo -u "$NGINX_USER" rm "$TEST_FILE" 2>/dev/null
else
    print_error "Failed to create test file as nginx user"
    print_info "This may indicate a persistent permissions issue"
    
    # Check for additional permissions issues
    print_info "Checking for additional restrictions..."
    
    # Check for immutable attribute
    if command -v lsattr >/dev/null 2>&1; then
        IMMUTABLE=$(lsattr -d "$HLS_DIR" 2>/dev/null | grep -o "i")
        if [ -n "$IMMUTABLE" ]; then
            print_error "Directory has immutable flag set"
            print_info "Removing immutable flag..."
            chattr -i "$HLS_DIR"
        fi
    fi
    
    # Check filesystem mount options
    FS_MOUNT=$(df -P "$HLS_DIR" | tail -1 | awk '{print $6}')
    FS_OPTIONS=$(mount | grep " $FS_MOUNT " | head -1 | awk -F '(' '{print $2}' | tr -d ')')
    print_info "Filesystem mount point: $FS_MOUNT"
    print_info "Mount options: $FS_OPTIONS"
    
    if echo "$FS_OPTIONS" | grep -q "ro,"; then
        print_error "Filesystem is mounted read-only"
    fi
    
    # Set temporary very permissive permissions for testing
    print_info "Setting temporary full permissions for testing..."
    chmod -R 777 "$HLS_DIR"
    
    if sudo -u "$NGINX_USER" touch "$TEST_FILE" 2>/dev/null; then
        print_success "Test file created with 777 permissions"
        sudo -u "$NGINX_USER" rm "$TEST_FILE" 2>/dev/null
        print_info "Consider keeping these permissions for testing, but secure them later"
    else
        print_error "Still cannot write to directory even with 777 permissions"
        print_info "This may indicate a serious system issue or mount restrictions"
    fi
fi

# Check parent directory permissions
print_header "Checking Parent Directory Permissions"

PARENT_DIR=$(dirname "$HLS_DIR")
PARENT_PERMS=$(stat -c "%a" "$PARENT_DIR" 2>/dev/null || stat -f "%p" "$PARENT_DIR" 2>/dev/null | cut -c 3-5)
PARENT_OWNER=$(stat -c "%U" "$PARENT_DIR" 2>/dev/null || stat -f "%Su" "$PARENT_DIR" 2>/dev/null)
PARENT_GROUP=$(stat -c "%G" "$PARENT_DIR" 2>/dev/null || stat -f "%Sg" "$PARENT_DIR" 2>/dev/null)

print_info "Parent directory: $PARENT_DIR"
print_info "Parent permissions: $PARENT_PERMS ($PARENT_OWNER:$PARENT_GROUP)"

# Check if nginx can traverse the parent directory
if sudo -u "$NGINX_USER" test -x "$PARENT_DIR" 2>/dev/null; then
    print_success "Parent directory is traversable by nginx user"
else
    print_error "Parent directory is not traversable by nginx user"
    print_info "Fixing parent directory permissions..."
    chmod +x "$PARENT_DIR"
    
    if sudo -u "$NGINX_USER" test -x "$PARENT_DIR" 2>/dev/null; then
        print_success "Successfully fixed parent directory permissions"
    else
        print_error "Failed to fix parent directory permissions"
    fi
fi

# Restart nginx if needed
print_header "Checking Nginx Status"

if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
    
    print_info "Would you like to restart Nginx to apply changes? (y/n): "
    read -r restart_nginx
    
    if [ "$restart_nginx" = "y" ]; then
        systemctl restart nginx
        if [ $? -eq 0 ]; then
            print_success "Nginx restarted successfully"
        else
            print_error "Failed to restart Nginx"
        fi
    fi
else
    print_error "Nginx is not running"
    print_info "Would you like to start Nginx? (y/n): "
    read -r start_nginx
    
    if [ "$start_nginx" = "y" ]; then
        systemctl start nginx
        if [ $? -eq 0 ]; then
            print_success "Nginx started successfully"
        else
            print_error "Failed to start Nginx"
        fi
    fi
fi

# Display location info
print_header "HLS Directory Information"

echo "HLS Directory: $HLS_DIR"
echo "Owner: $(stat -c "%U" "$HLS_DIR" 2>/dev/null || stat -f "%Su" "$HLS_DIR" 2>/dev/null)"
echo "Group: $(stat -c "%G" "$HLS_DIR" 2>/dev/null || stat -f "%Sg" "$HLS_DIR" 2>/dev/null)"
echo "Permissions: $(stat -c "%a" "$HLS_DIR" 2>/dev/null || stat -f "%p" "$HLS_DIR" 2>/dev/null | cut -c 3-5)"
echo "Nginx User: $NGINX_USER"

# Display location of HLS files in nginx config
echo ""
print_info "HLS location in Nginx configuration:"
if [ -n "$NGINX_CONF_FILES" ]; then
    for conf in $NGINX_CONF_FILES; do
        echo "- $conf"
    done
fi

# Display URL path for HLS
echo ""
print_info "HLS URL path in Nginx:"
for conf_file in $(find /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx -type f -name "*.conf" 2>/dev/null); do
    if grep -q "location /hls" "$conf_file"; then
        echo "Found in $conf_file:"
        grep -A 5 "location /hls" "$conf_file" | head -6
        break
    fi
done

# Summary
print_header "Summary"

echo "✅ HLS directory check completed"
echo "✅ Directory: $HLS_DIR"
echo "✅ Nginx user: $NGINX_USER"
echo ""
echo "If you're still having issues with HLS streaming:"
echo "1. Check the nginx error logs: tail -f /var/log/nginx/error.log"
echo "2. Make sure the RTMP module is properly configured"
echo "3. Verify that your streaming software is correctly connected"
echo "4. Try accessing the HLS stream directly: http://YOUR_SERVER/hls/STREAM_KEY.m3u8"
echo ""
print_success "Script completed successfully!"