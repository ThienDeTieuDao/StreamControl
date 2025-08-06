# RTMP Streaming Troubleshooting Guide

This guide will help you troubleshoot RTMP streaming issues with your StreamLite installation.

## Common Issues and Solutions

### 1. Connection to RTMP Server Fails (Connection Refused or Timeout)

**Symptoms:**
- Error messages like: "Connection to tcp://hwosecurity.org:1935 failed: Connection refused" or "Connection timed out"
- Unable to start streaming from OBS, FFmpeg, or other streaming software

**Solutions:**

#### Check if RTMP service is running:
```bash
sudo netstat -tuln | grep 1935
```
If nothing shows up, the RTMP service is not running or not properly configured.

#### Verify nginx with RTMP module is installed:
```bash
nginx -V 2>&1 | grep rtmp
```
If you don't see rtmp in the output, you need to install nginx with RTMP support.

#### Check firewall settings:
```bash
sudo ufw status
# or
sudo iptables -L -n | grep 1935
```
Make sure port 1935 is allowed through your firewall.

#### For cloud instances (AWS, GCP, Azure, etc.):
Make sure your security groups or network ACLs allow inbound traffic on port 1935.

#### Run the diagnostic script:
```bash
sudo bash ./fix_rtmp_streaming.sh
```

### 2. Stream Starts but No Video Appears in Player

**Symptoms:**
- Streaming software (OBS, FFmpeg) shows that the stream is active
- The HLS player doesn't show any video or shows an error

**Solutions:**

#### Check HLS directory permissions:
```bash
sudo ls -la /var/hls
# or wherever your HLS directory is located
```
Make sure the nginx user has write permissions.

#### Check nginx logs for errors:
```bash
sudo tail -f /var/log/nginx/error.log
```

#### Verify HLS files are being created:
```bash
ls -la /var/hls
```
You should see .m3u8 and .ts files being created for your stream.

#### Test the HLS endpoint directly:
```bash
curl -I http://hwosecurity.org/hls/your_stream_key.m3u8
```
This should return a 200 OK status if everything is working.

### 3. Stream Authentication Issues

**Symptoms:**
- Stream starts but then immediately disconnects
- Nginx error logs show authentication failures

**Solutions:**

#### Check authentication configuration:
1. Look for the `on_publish` directive in your RTMP configuration
2. Make sure the URL points to your Flask app's authentication endpoint
3. Verify the Flask app is running and accessible

#### Temporarily disable authentication for testing:
Comment out the `on_publish` line in your nginx RTMP configuration to test without authentication.

### 4. Connection to Private vs Public IP

If you're testing on the same server as your StreamLite installation:

1. Use the private IP or localhost for testing:
```bash
ffmpeg -re -i test.mp4 -c:v copy -c:a copy -f flv rtmp://127.0.0.1:1935/live/your_stream_key
```

2. For external connections, use the public IP or domain name:
```bash
ffmpeg -re -i test.mp4 -c:v copy -c:a copy -f flv rtmp://hwosecurity.org:1935/live/your_stream_key
```

3. Use the test_port script to check connectivity:
```bash
./test_port.sh hwosecurity.org 1935
```

## Step-by-Step Debugging Process

1. Verify nginx is running:
```bash
sudo systemctl status nginx
```

2. Check if RTMP port is listening:
```bash
sudo netstat -tuln | grep 1935
```

3. Test authentication endpoint:
```bash
curl -X POST -d "name=your_stream_key" http://localhost:5000/api/stream/auth
```
It should return a 200 status code if the stream key is valid.

4. Attempt a local stream:
```bash
cd /opt/streamlite/test
./test_rtmp_stream.sh
```
Choose option 3 (private IP) for local testing.

5. Check nginx error logs:
```bash
sudo tail -f /var/log/nginx/error.log
```

6. Inspect HLS segments:
```bash
ls -la /var/hls
```

7. Test HLS playback URL:
```bash
curl -I http://hwosecurity.org/hls/your_stream_key.m3u8
```

## Advanced Troubleshooting

### Network Connectivity Issues

If you suspect network connectivity issues:

1. Check if your server is reachable from the internet:
```bash
./test_port.sh hwosecurity.org 80
./test_port.sh hwosecurity.org 1935
```

2. Verify DNS resolution:
```bash
host hwosecurity.org
```

3. Check for routing issues:
```bash
traceroute hwosecurity.org
```

### Debugging RTMP Module

If you need to debug the nginx RTMP module:

1. Increase logging in nginx.conf:
```
error_log /var/log/nginx/error.log debug;
```

2. Restart nginx:
```bash
sudo systemctl restart nginx
```

3. Monitor detailed logs:
```bash
sudo tail -f /var/log/nginx/error.log
```

## Common RTMP Configuration

Here's a typical RTMP configuration for nginx:

```
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        application live {
            live on;
            record off;
            
            # HLS
            hls on;
            hls_path /var/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # Authentication (comment out for testing)
            on_publish http://localhost:5000/api/stream/auth;
        }
    }
}
```

## Getting Help

If you're still experiencing issues after trying these troubleshooting steps:

1. Check the full logs:
```bash
journalctl -u nginx
```

2. Verify all components are running:
```bash
sudo systemctl status nginx
sudo systemctl status flask-app  # or whatever your app service is named
```

3. Gather system information:
```bash
uname -a
nginx -V
cat /etc/nginx/nginx.conf
```

With this information, you'll be better equipped to get help from the StreamLite community or support team.