#!/usr/bin/env python
"""
Simple script to check if the WebRTC server is running.
"""

import os
import socket
import ssl
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def check_port(hostname, port):
    """Check if a port is open on a hostname."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((hostname, port))
        sock.close()
        return result == 0
    except Exception as e:
        print(f"Error checking port: {e}")
        return False

def check_ssl_cert(hostname, port):
    """Check if a valid SSL certificate exists for hostname:port."""
    try:
        context = ssl.create_default_context()
        with socket.create_connection((hostname, port)) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
                print(f"SSL Certificate: {cert}")
                return True
    except Exception as e:
        print(f"Error checking SSL: {e}")
        return False

def main():
    """Main function to check WebRTC server status."""
    hostname = 'hwosecurity.org'
    webrtc_port = 5443
    
    # Check WebRTC port
    print(f"Checking if WebRTC server is running on {hostname}:{webrtc_port}...")
    if check_port(hostname, webrtc_port):
        print(f"✅ WebRTC server is running on {hostname}:{webrtc_port}")
    else:
        print(f"❌ WebRTC server is NOT running on {hostname}:{webrtc_port}")
    
    # Check SSL certificates
    cert_file = os.environ.get('SSL_CERT_FILE')
    key_file = os.environ.get('SSL_KEY_FILE')
    
    print("\nChecking SSL certificate configuration...")
    if cert_file and os.path.exists(cert_file):
        print(f"✅ SSL certificate file exists: {cert_file}")
    else:
        print(f"❌ SSL certificate file not found: {cert_file}")
    
    if key_file and os.path.exists(key_file):
        print(f"✅ SSL key file exists: {key_file}")
    else:
        print(f"❌ SSL key file not found: {key_file}")
    
    print("\nChecking SSL certificate validity...")
    if check_ssl_cert(hostname, 443):
        print(f"✅ Valid SSL certificate for {hostname}")
    else:
        print(f"❌ Invalid or missing SSL certificate for {hostname}")

if __name__ == "__main__":
    main()