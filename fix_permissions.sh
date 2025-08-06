#!/bin/bash
# Script to fix PostgreSQL permissions for StreamLite
# Run this as the postgres user or with sudo

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_info() {
    echo -e "${YELLOW}$1${NC}"
}

# Check if running as root or postgres
if [[ $EUID -ne 0 ]] && [[ "$(whoami)" != "postgres" ]]; then
    print_error "This script must be run as root or as the postgres user"
    print_info "Try: sudo -u postgres bash fix_permissions.sh"
    exit 1
fi

# Database info
DB_NAME=${1:-"streamlite"}
DB_USER=${2:-"streamlite"}

print_info "Fixing PostgreSQL permissions for database: $DB_NAME and user: $DB_USER"

# If running as root, switch to postgres user
if [[ $EUID -eq 0 ]]; then
    print_info "Running as root, switching to postgres user"
    sudo -u postgres bash -c "psql -c \"ALTER USER $DB_USER WITH SUPERUSER;\""
    sudo -u postgres bash -c "psql -d $DB_NAME -c \"GRANT ALL ON SCHEMA public TO $DB_USER;\""
    sudo -u postgres bash -c "psql -d $DB_NAME -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;\""
    sudo -u postgres bash -c "psql -d $DB_NAME -c \"GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;\""
    sudo -u postgres bash -c "psql -d $DB_NAME -c \"GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;\""
else
    # Running as postgres user
    psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
    psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
    psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;"
fi

# Verify the permissions were granted successfully
if [ $? -eq 0 ]; then
    print_success "PostgreSQL permissions successfully updated for user $DB_USER on database $DB_NAME"
    print_info "The StreamLite application should now be able to create tables and manage the database properly."
else
    print_error "Failed to update PostgreSQL permissions"
    print_info "You may need to manually run the commands in the PostgreSQL shell."
fi

print_info "If you continue to experience permission issues, you might need to set:"
print_info "1. PGUSER in your .env file to a PostgreSQL superuser"
print_info "2. Or reconfigure PostgreSQL's pg_hba.conf file for less restrictive permissions"