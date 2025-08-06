# StreamLite Installation Guide for AaPanel

This guide provides step-by-step instructions for installing StreamLite on a server running AaPanel.

## Prerequisites

- AaPanel installation with admin access
- Ubuntu 20.04 or CentOS 8 (recommended)
- Domain pointed to your server
- Basic knowledge of Linux commands

## Installation Steps

### 1. Preparing Your Web Environment

1. Log in to your AaPanel dashboard.
2. Go to **Website** and create a new website for your domain.
   - Set the domain name (e.g., `yourdomain.com`)
   - Choose PHP version (not important as we'll be using Python)
   - Create the website

### 2. Installing Required Packages

AaPanel provides an App Store to easily install required packages:

1. In AaPanel, go to **App Store**.
2. Find and install the following packages:
   - **Python Project Manager** (supports Python 3.7+)
   - **Supervisor** (for process management)
   - **Nginx** (likely already installed)
   - **PostgreSQL** or **MySQL** (depending on your preference)
   - **FFmpeg** (may need to be installed via command line)

If FFmpeg is not available in the App Store, install it via command line:
```bash
# For Ubuntu/Debian
apt-get update
apt-get install -y ffmpeg

# For CentOS
yum install -y epel-release
yum install -y ffmpeg ffmpeg-devel
```

### 3. Setting Up Your Project Directory

1. Connect to your server via SSH or use the AaPanel Terminal.
2. Navigate to your website root directory (typically `/www/wwwroot/yourdomain.com`).
3. Upload your StreamLite files to this directory.

### 4. Creating a Python Virtual Environment

1. Navigate to your project directory:
   ```bash
   cd /www/wwwroot/yourdomain.com
   ```

2. Install the Python virtual environment package (if not already installed):
   ```bash
   # For Ubuntu/Debian
   apt install python3-venv
   
   # For Ubuntu 20.04+ with specific Python version
   apt install python3.10-venv  # Replace 3.10 with your Python version
   
   # For CentOS/RHEL
   yum install python3-devel
   ```

3. Create a virtual environment:
   ```bash
   python3 -m venv venv
   ```
   
   If you encounter the error "ensurepip is not available," it means the Python venv package is not installed. Use the commands in step 2 to install it.

4. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```

5. Install required packages:
   ```bash
   pip install -r requirements.txt
   ```

### 5. Database Configuration

#### For PostgreSQL:

1. In AaPanel, go to **Database** > **PostgreSQL**.
2. Click **Add Database**.
3. Create a database (e.g., `streamlite`).
4. Create a database user and set a secure password.
5. Note down the database name, username, and password.

#### For MySQL:

1. In AaPanel, go to **Database** > **MySQL**.
2. Click **Add Database**.
3. Create a database (e.g., `streamlite`).
4. Create a database user and set a secure password.
5. Note down the database name, username, and password.

### 6. Creating and Managing Environment Configuration

Create a `.env` file in your application directory with the following content:

```
# Database Configuration (for PostgreSQL)
DATABASE_URL="postgresql://username:password@localhost/streamlite"
PGDATABASE="streamlite"
PGUSER="streamlite_user"
PGPASSWORD="your_password"
PGHOST="localhost"
PGPORT=5432

# OR for MySQL
# DATABASE_URL="mysql://username:password@localhost/streamlite"

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="your-secure-random-string"
UPLOAD_FOLDER="/www/wwwroot/yourdomain.com/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO

# RTMP Settings
RTMP_SERVER=rtmp://yourdomain.com/live
```

Replace the placeholders with your actual credentials and paths.

#### Managing Environment Variables in AaPanel

There are several ways to update your environment variables in AaPanel:

1. **Using AaPanel File Manager**:
   - In AaPanel, go to **Files**
   - Navigate to your website directory (`/www/wwwroot/yourdomain.com`)
   - Right-click on the `.env` file and select **Edit**
   - Make your changes and save the file
   - Restart your application through Supervisor

2. **Using SSH Terminal**:
   - In AaPanel, open the **Terminal** or connect via SSH
   - Use a text editor to modify the file:
     ```bash
     nano /www/wwwroot/yourdomain.com/.env
     ```
   - Make your changes, save the file (Ctrl+O, then Enter), and exit (Ctrl+X)
   - Restart your application via Supervisor:
     ```bash
     supervisorctl restart streamlite
     ```

3. **Using Supervisor Environment Variables**:
   - In AaPanel, go to **App Store** > **Supervisor**
   - Click on your StreamLite application
   - Under **Configuration**, you can edit the **Environment Variables**
   - Add variables in KEY=VALUE format, one per line
   - Save and restart the Supervisor process
   - Note: For comprehensive configuration, the `.env` file is generally recommended over this method

### 7. Initializing the Database

1. With your virtual environment activated, run:
   ```bash
   python initialize.py
   ```

2. This will create all necessary database tables and an admin user.

### 8. Configuring NGINX with AaPanel

1. In AaPanel, go to **Website**.
2. Click on your domain, then select **Settings**.
3. Click on **Configure**.
4. Replace the default configuration with a custom one similar to the following:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Redirect HTTP to HTTPS (if SSL is enabled)
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    
    # SSL configuration (generated by AaPanel)
    ssl_certificate /www/server/panel/vhost/cert/yourdomain.com/fullchain.pem;
    ssl_certificate_key /www/server/panel/vhost/cert/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    # Static files
    location /static {
        alias /www/wwwroot/yourdomain.com/static;
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }
    
    # Uploads
    location /uploads {
        alias /www/wwwroot/yourdomain.com/uploads;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    # Proxy requests to Gunicorn
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
}
```

5. Click **Save** to update the configuration.

### 9. Setting Up Supervisor for Process Management

1. In AaPanel, go to **App Store** > **Supervisor**.
2. Click **Add Supervisor**.
3. Configure the Supervisor task:
   - **Name**: StreamLite
   - **Command**: 
     ```
     /www/wwwroot/yourdomain.com/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 main:app
     ```
   - **User**: www (or your website user)
   - **Working Directory**: `/www/wwwroot/yourdomain.com`
   - **Auto Start**: Yes
   - **Process Number**: 1
4. Click **Submit** to create the Supervisor task.

### 10. Setting Up RTMP for Live Streaming (Optional)

To enable RTMP for live streaming, you'll need to compile Nginx with the RTMP module:

1. Stop the Nginx service from AaPanel.
2. Install necessary build tools:
   ```bash
   # For Ubuntu/Debian
   apt-get install -y build-essential libpcre3-dev libssl-dev
   
   # For CentOS
   yum install -y gcc-c++ pcre-devel openssl-devel
   ```
3. Download and compile Nginx with RTMP module:
   ```bash
   wget https://nginx.org/download/nginx-1.20.2.tar.gz
   wget https://github.com/arut/nginx-rtmp-module/archive/master.zip
   unzip master.zip
   tar -xzf nginx-1.20.2.tar.gz
   cd nginx-1.20.2
   
   ./configure --prefix=/www/server/nginx --add-module=../nginx-rtmp-module-master --with-http_ssl_module --with-http_v2_module
   
   make
   make install
   ```
4. Update your Nginx configuration to include RTMP settings from the sample configuration.
5. Restart Nginx from AaPanel.

### 11. Setting Up SSL

1. In AaPanel, go to **SSL**.
2. Select your domain.
3. Choose one of the following options:
   - **Apply Let's Encrypt Certificate** (free)
   - **Upload Custom Certificate** (if you have your own)
4. Follow the prompts to complete the SSL setup.

### 12. Final Steps

1. Start your application via Supervisor from the AaPanel interface.
2. Test your application by accessing your domain in a web browser.
3. Log in with the default admin credentials:
   - Username: `admin`
   - Password: `streamlite_admin` (change this immediately!)
4. Go to Admin → Site Settings to customize your streaming platform.

## Troubleshooting

### Common Issues in AaPanel

1. **Nginx Not Starting**:
   - Check Nginx error logs: `/www/wwwlogs/nginx_error.log`
   - Verify your custom Nginx configuration has correct syntax.

2. **Application Not Running**:
   - Check Supervisor logs from the AaPanel interface.
   - Ensure the virtual environment path is correct in your Supervisor command.

3. **Database Connection Issues**:
   - Verify the database credentials in your `.env` file.
   - Check if the database is running: `systemctl status postgresql` or `systemctl status mysql`.

4. **Permission Issues**:
   - Ensure the uploads directory has correct permissions:
     ```bash
     chown -R www:www /www/wwwroot/yourdomain.com/uploads
     chmod -R 755 /www/wwwroot/yourdomain.com/uploads
     ```

5. **RTMP Streaming Not Working**:
   - Check if the custom RTMP module is properly loaded by Nginx.
   - Verify port 1935 (RTMP) is open in your firewall.

For additional help with AaPanel-specific issues, refer to the [AaPanel Documentation](https://www.aapanel.com/docs/)