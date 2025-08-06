#!/bin/bash

# Simple script to test if a port is open on a host
# Usage: ./test_port.sh <host> <port>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <host> <port>${NC}"
    exit 1
fi

HOST=$1
PORT=$2

echo -e "${YELLOW}Testing connection to $HOST on port $PORT...${NC}"

# Try nc if available
if command -v nc >/dev/null; then
    if nc -z -w 5 $HOST $PORT 2>/dev/null; then
        echo -e "${GREEN}✓ Success! Port $PORT is open on $HOST${NC}"
        exit 0
    fi
# Try telnet if available
elif command -v telnet >/dev/null; then
    if timeout 5 telnet $HOST $PORT 2>/dev/null | grep -q Connected; then
        echo -e "${GREEN}✓ Success! Port $PORT is open on $HOST${NC}"
        exit 0
    fi
# Try curl as a last resort
elif command -v curl >/dev/null; then
    if curl -s --connect-timeout 5 $HOST:$PORT >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Success! Port $PORT is open on $HOST${NC}"
        exit 0
    fi
fi

echo -e "${RED}✗ Failed! Port $PORT is closed or unreachable on $HOST${NC}"

# If we failed, try to give some additional diagnostic information
echo -e "${YELLOW}Additional diagnostics:${NC}"

# Check if the host resolves
if command -v host >/dev/null; then
    echo -n "DNS Lookup: "
    host $HOST || echo "Failed to resolve hostname"
elif command -v nslookup >/dev/null; then
    echo -n "DNS Lookup: "
    nslookup $HOST || echo "Failed to resolve hostname"
elif command -v dig >/dev/null; then
    echo -n "DNS Lookup: "
    dig +short $HOST || echo "Failed to resolve hostname"
fi

# Try traceroute to see where the connection fails
if command -v traceroute >/dev/null; then
    echo "Traceroute to $HOST (limited to 10 hops):"
    traceroute -m 10 $HOST 2>/dev/null || echo "Traceroute failed"
fi

# Check for local firewalls
echo "Checking local firewall status:"
if command -v ufw >/dev/null; then
    ufw status | grep -q "Status: active" && echo "UFW is active" || echo "UFW is inactive"
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --state && echo "FirewallD is active" || echo "FirewallD is inactive"
elif command -v iptables >/dev/null; then
    iptables -L -n | grep -q "Chain INPUT" && echo "iptables rules exist" || echo "No iptables rules found"
fi

# Offer suggestions
echo -e "\n${YELLOW}Suggestions:${NC}"
echo "1. Check if the server at $HOST is running and listening on port $PORT"
echo "2. Verify that no firewall is blocking the connection"
echo "3. If using a domain name, ensure DNS is resolving to the correct IP address"
echo "4. For cloud instances, check security groups or network ACLs"

exit 1