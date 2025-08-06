# StreamLite Installation Guide for CyberPanel

This guide provides detailed steps for installing StreamLite on a CyberPanel managed server.

## Prerequisites

Before starting, ensure you have:

1. A CyberPanel-managed server running Ubuntu 20.04 or later
2. SSH access to your server
3. Python 3.8+ installed
4. Basic knowledge of command line operations

## Installation Steps

### 1. Setting Up Website in CyberPanel

1. Log in to your CyberPanel admin interface.
2. Navigate to **Websites** > **Create Website**.
3. Enter your domain name and other required details.
4. Select the appropriate package and click **Create Website**.

### 2. Configure Python Application (Optional)

If CyberPanel has a Python App configuration option:

1. Go to **Websites** > **List Websites**.
2. Select your website.
3. Look for a **Python App** or similar option.
4. Configure the Python application settings:
   - **Application Directory**: Path to your application (typically `/home/username/streamlite`)
   - **Application Startup File**: `main.py`
   - **Application Entry Point**: `app`
   - **Python Version**: Select 3.8 or higher

### 3. Setting Up Virtual Environment Manually

To set up a virtual environment for StreamLite:

1. Connect to your server via SSH.
2. Navigate to your application directory:
   ```bash
   cd /home/username/streamlite
   ```

3. Install the Python virtual environment package (if not already installed):
   
   ```bash
   # For Ubuntu/Debian
   sudo apt install python3-venv
   
   # For Ubuntu 20.04+ with specific Python version
   sudo apt install python3.10-venv  # Replace 3.10 with your Python version
   
   # For CentOS/RHEL
   sudo yum install python3-devel
   ```

4. Create a virtual environment:
   ```bash
   python3 -m venv venv
   ```
   
   If you encounter the error "ensurepip is not available," it means the Python venv package is not installed. Use the commands in step 3 to install it.

5. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```

6. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### 4. Database Configuration

1. In CyberPanel, navigate to **Databases** section.
2. Create a new MySQL or PostgreSQL database.
3. Create a new database user and set a secure password.
4. Add the user to the database with all privileges.
5. Note down the database name, username, and password.

### 5. Creating and Managing Environment Configuration

Create a `.env` file in your application directory with the following content:

```
# Database Configuration (for MySQL)
DATABASE_URL="mysql://username_streamuser:password@localhost/username_streamlite"

# OR for PostgreSQL
# DATABASE_URL="postgresql://username_streamuser:password@localhost/username_streamlite"

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="your-secure-random-string"
UPLOAD_FOLDER="/home/username/streamlite/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO

# RTMP Settings (if using RTMP)
RTMP_SERVER=rtmp://yourdomain.com/live
```

Replace the placeholders with your actual credentials and paths.

#### Managing Environment Variables in CyberPanel

You can manage your environment variables in CyberPanel:

1. **Using File Manager**:
   - Go to CyberPanel > **File Manager**
   - Navigate to your application directory
   - Create or edit the `.env` file
   - Save your changes

2. **Using SSH**:
   - Connect to your server via SSH
   - Use a text editor like nano or vim to edit the file:
     ```bash
     nano /home/username/streamlite/.env
     ```
   - Make your changes, save the file, and exit the editor

### 6. Initializing the Database

1. Connect to your server via SSH.
2. Navigate to your application directory:
   ```bash
   cd /home/username/streamlite
   ```
3. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```
4. Run the initialization script:
   ```bash
   python initialize.py
   ```

### 7. Setting Up Gunicorn for Production

1. Create a `gunicorn_starter.sh` file in your application directory:
   ```bash
   #!/bin/bash
   cd /home/username/streamlite
   source venv/bin/activate
   gunicorn --workers 4 --bind 0.0.0.0:5000 --log-level warning main:app
   ```

2. Make the script executable:
   ```bash
   chmod +x gunicorn_starter.sh
   ```

3. Create a supervisor configuration file:
   ```bash
   sudo nano /etc/supervisor/conf.d/streamlite.conf
   ```

4. Add the following content:
   ```
   [program:streamlite]
   command=/home/username/streamlite/gunicorn_starter.sh
   directory=/home/username/streamlite
   user=username
   autostart=true
   autorestart=true
   stderr_logfile=/home/username/streamlite/logs/gunicorn.err.log
   stdout_logfile=/home/username/streamlite/logs/gunicorn.out.log
   ```

5. Create a logs directory:
   ```bash
   mkdir -p /home/username/streamlite/logs
   ```

6. Update supervisor:
   ```bash
   sudo supervisorctl reread
   sudo supervisorctl update
   sudo supervisorctl start streamlite
   ```

### 8. Configuring Nginx Reverse Proxy

1. In CyberPanel, go to your website's configuration.
2. Look for an option to edit Nginx configuration or add custom Nginx directives.
3. Add the following configuration (adjust based on your CyberPanel interface):

   ```nginx
   location / {
       proxy_pass http://127.0.0.1:5000;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       
       # WebSocket support
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_read_timeout 86400;
   }

   location /static {
       alias /home/username/streamlite/static;
       expires 30d;
       access_log off;
       add_header Cache-Control "public";
   }
   
   location /uploads {
       alias /home/username/streamlite/uploads;
       expires 7d;
       add_header Cache-Control "public";
   }
   ```

4. Save the configuration and restart Nginx:
   ```bash
   sudo systemctl restart nginx
   ```

### 9. RTMP Setup for Live Streaming (Optional)

If you need RTMP for live streaming:

1. Install Nginx with RTMP module (requires root access):
   ```bash
   sudo apt update
   sudo apt install -y build-essential libpcre3-dev libssl-dev
   sudo apt install -y nginx libnginx-mod-rtmp
   ```

2. Create an Nginx RTMP configuration file:
   ```bash
   sudo nano /etc/nginx/modules-enabled/rtmp.conf
   ```

3. Add the following content:
   ```nginx
   rtmp {
       server {
           listen 1935;
           chunk_size 4096;
           
           application live {
               live on;
               record off;
               
               # HLS streaming
               hls on;
               hls_path /home/username/streamlite/hls;
               hls_fragment 3;
               hls_playlist_length 60;
               
               # on_publish authentication handler
               on_publish http://127.0.0.1:5000/live/auth;
               on_publish_done http://127.0.0.1:5000/live/done;
           }
       }
   }
   ```

4. Create the HLS directory:
   ```bash
   mkdir -p /home/username/streamlite/hls
   chmod -R 755 /home/username/streamlite/hls
   ```

5. Restart Nginx:
   ```bash
   sudo systemctl restart nginx
   ```

### 10. Final Steps

1. Test your application by accessing your domain in a web browser.
2. Log in with the default admin credentials:
   - Username: `admin`
   - Password: `streamlite_admin` (change this immediately!)
3. Go to Admin → Site Settings to customize your streaming platform.

## Troubleshooting

### Common Issues in CyberPanel

1. **500 Internal Server Error**:
   - Check the error logs in your application's log directory or CyberPanel's error logs.
   - Ensure file permissions are correct (755 for directories, 644 for files).
   - Verify the `.env` file contains the correct paths.

2. **Application Not Starting**:
   - Check supervisor logs:
     ```bash
     sudo supervisorctl status streamlite
     sudo cat /home/username/streamlite/logs/gunicorn.err.log
     ```
   - Ensure Gunicorn is installed in your virtual environment.

3. **Database Connection Issues**:
   - Verify the database credentials in your `.env` file.
   - Ensure the database user has the correct permissions.
   - Check if the database server is running.

4. **File Upload Problems**:
   - Check the permissions on your upload directory.
   - Ensure your PHP settings (if applicable) allow for file uploads of your desired size.
   - Verify the `UPLOAD_FOLDER` path in your `.env` file.

5. **RTMP Streaming Issues**:
   - Ensure Nginx is compiled with RTMP module support.
   - Check Nginx error logs for RTMP-related issues:
     ```bash
     sudo cat /var/log/nginx/error.log
     ```
   - Verify that port 1935 is open in your firewall.

For additional help, refer to the CyberPanel documentation or contact their support for CyberPanel-specific issues.

## Maintenance and Updates

### Updating StreamLite

To update StreamLite to the latest version:

1. Connect to your server via SSH.
2. Navigate to your application directory:
   ```bash
   cd /home/username/streamlite
   ```
3. Pull the latest code (if using Git):
   ```bash
   git pull origin main
   ```
4. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```
5. Install any new dependencies:
   ```bash
   pip install -r requirements.txt
   ```
6. Restart the application:
   ```bash
   sudo supervisorctl restart streamlite
   ```

### Backup and Recovery

Regularly back up your database and uploaded content:

1. **Database Backup**:
   - For MySQL:
     ```bash
     mysqldump -u username -p database_name > backup.sql
     ```
   - For PostgreSQL:
     ```bash
     pg_dump -U username database_name > backup.sql
     ```

2. **File Backup**:
   - Back up the uploads directory:
     ```bash
     tar -czf uploads_backup.tar.gz /home/username/streamlite/uploads
     ```

3. **Configuration Backup**:
   - Back up your environment file:
     ```bash
     cp /home/username/streamlite/.env .env.backup
     ```

Store these backups in a secure location, preferably off-server.