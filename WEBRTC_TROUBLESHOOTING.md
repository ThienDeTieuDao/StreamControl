# WebRTC Streaming Troubleshooting Guide

This guide helps you troubleshoot issues with WebRTC streaming in StreamLite.

## Table of Contents

1. [What is WebRTC?](#what-is-webrtc)
2. [Prerequisites](#prerequisites)
3. [Common Issues](#common-issues)
4. [Connection Problems](#connection-problems)
5. [Video/Audio Quality Issues](#videoaudio-quality-issues)
6. [Browser Compatibility](#browser-compatibility)
7. [Port and Firewall Configuration](#port-and-firewall-configuration)
8. [SSL Certificate Issues](#ssl-certificate-issues)
9. [Server Configuration](#server-configuration)
10. [Diagnosing with test_webrtc.sh](#diagnosing-with-test_webrtcsh)

## What is WebRTC?

WebRTC (Web Real-Time Communication) is an open-source project that enables real-time communication directly in browsers and mobile applications through simple APIs. It allows audio, video, and data to be exchanged between peers without requiring plugins or downloads.

**Benefits of WebRTC:**
- Low latency (typically 500ms or less)
- Direct peer-to-peer connections where possible
- Built-in encryption (DTLS)
- No plugins required
- Works across modern browsers

## Prerequisites

For WebRTC streaming to work properly, you need:

1. **Modern Browser Support**: Chrome, Firefox, Safari, Edge (latest versions)
2. **HTTPS/SSL**: WebRTC requires secure contexts (HTTPS)
3. **Open Ports**: WebRTC uses port 5443 in StreamLite
4. **Server Requirements**:
   - Python 3.7+
   - aiohttp
   - aiortc
   - python-socketio

## Common Issues

### WebRTC Server Not Starting

**Symptoms:**
- Unable to connect to WebRTC server
- "Connection refused" errors
- Server not responding on port 5443

**Solutions:**
1. Verify the WebRTC service is running as separate process in the main application:
   ```bash
   ps aux | grep webrtc_server.py
   ```

2. Check logs for errors:
   ```bash
   tail -n 50 /var/log/streamlite/webrtc.log
   ```

3. Restart the WebRTC server by restarting the main application:
   ```bash
   systemctl restart hwosecurity
   ```

4. Make sure required Python packages are installed:
   ```bash
   pip install aiohttp aiortc python-socketio
   ```

5. For hwosecurity.org, verify that https://hwosecurity.org:5443/webrtc is accessible in browser.

6. Check the .env file for proper SSL certificate paths:
   ```
   SSL_CERT_FILE=/etc/letsencrypt/live/hwosecurity.org/fullchain.pem
   SSL_KEY_FILE=/etc/letsencrypt/live/hwosecurity.org/privkey.pem
   ```

### Connection Problems

**Symptoms:**
- "Failed to connect" errors
- Connection attempts time out
- "ICE connection failed" errors in browser console

**Solutions:**
1. Check that port 5443 is open and accessible:
   ```bash
   netstat -tuln | grep 5443
   ```

2. Verify port forwarding if behind NAT/router:
   ```bash
   ./test_webrtc.sh
   ```

3. Test SSL connectivity:
   ```bash
   openssl s_client -connect hwosecurity.org:5443
   ```

4. Check that STUN/TURN servers are properly configured (if needed for NAT traversal)

## Video/Audio Quality Issues

**Symptoms:**
- Pixelated video
- Audio dropouts
- Stuttering playback
- High latency

**Solutions:**
1. Check bandwidth availability
2. Lower video resolution in browser settings
3. Verify CPU usage isn't too high
4. Check network quality between peers
5. Reduce browser extensions that might interfere

## Browser Compatibility

WebRTC is supported by most modern browsers, but implementation details can vary.

**Most Compatible Browsers:**
1. Google Chrome (v60+)
2. Mozilla Firefox (v52+)
3. Microsoft Edge (v79+)
4. Safari (v11+)

**Troubleshooting Browser Issues:**
1. Clear browser cache and cookies
2. Disable browser extensions
3. Try a different browser
4. Update browser to latest version
5. Check browser console for errors (F12 or Ctrl+Shift+I)

## Port and Firewall Configuration

WebRTC requires specific ports to be open:

1. **TCP port 5443** for the WebRTC signaling server
2. **UDP ports** (range varies) for media data

**Firewall Configuration Commands:**

For UFW:
```bash
sudo ufw allow 5443/tcp
```

For FirewallD:
```bash
sudo firewall-cmd --permanent --add-port=5443/tcp
sudo firewall-cmd --reload
```

For iptables:
```bash
sudo iptables -A INPUT -p tcp --dport 5443 -j ACCEPT
```

## SSL Certificate Issues

WebRTC requires a valid SSL certificate.

**Symptoms:**
- "Secure connection failed" errors
- Browser blocks connection
- Certificate warnings

**Solutions:**
1. Ensure your SSL certificate is valid and not expired:
   ```bash
   openssl x509 -in /path/to/certificate.crt -text -noout | grep "Not After"
   ```

2. Verify certificate is properly installed:
   ```bash
   ./test_webrtc.sh
   ```

3. If using Let's Encrypt, make sure certificates are auto-renewing:
   ```bash
   certbot certificates
   ```

## Server Configuration

The WebRTC server runs on port 5443 by default. Make sure this port is not being used by other services.

1. Check nginx configuration:
   ```bash
   grep -r "5443" /etc/nginx/
   ```

2. Verify the service configuration:
   ```bash
   systemctl cat webrtc.service
   ```

3. Check for Python processes using the port:
   ```bash
   ps aux | grep python | grep -i webrtc
   ```

## Diagnosing with test_webrtc.sh

StreamLite includes a diagnostic script for WebRTC:

```bash
./test_webrtc.sh
```

This script checks:
1. If WebRTC port is open and listening
2. Firewall configuration
3. SSL certificate status
4. Required dependencies
5. Connection testing

## Debugging Connection Issues

When users cannot connect, check:

1. **WebRTC Service Status**:
   ```bash
   systemctl status webrtc
   ```

2. **Recent Error Logs**:
   ```bash
   tail -n 50 /var/log/webrtc/error.log
   ```

3. **Network Connectivity**:
   ```bash
   ping hwosecurity.org
   traceroute hwosecurity.org
   ```

4. **SSL Certificate Validity**:
   ```bash
   openssl s_client -connect hwosecurity.org:5443 -servername hwosecurity.org
   ```

5. **Resource Usage**:
   ```bash
   top
   free -h
   df -h
   ```

## Restarting the WebRTC Server

If you make configuration changes or encounter issues, restart the server:

```bash
systemctl restart webrtc
```

---

For additional help, check the application logs or contact your system administrator.