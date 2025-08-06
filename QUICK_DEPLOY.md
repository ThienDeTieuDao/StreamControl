# Quick Deploy Guide for StreamLite

This is a quick deploy reference for streamlite on a VPS, specifically optimized for AaPanel environments.

## Prerequisites

- Ubuntu 20.04 or later
- AaPanel installed
- Python 3.8 or later
- PostgreSQL 12 or later
- Nginx

## 1. Rapid Deployment Steps

### Clone or Upload StreamLite

```bash
# Navigate to your web directory
cd /www/wwwroot/yourdomain.com

# Clear existing files if necessary
rm -rf *

# Clone or upload StreamLite here
# ...

# Set permissions
chown -R www:www /www/wwwroot/yourdomain.com
chmod -R 755 /www/wwwroot/yourdomain.com
```

### Setup Python Environment

```bash
# Create virtual environment
cd /www/wwwroot/yourdomain.com
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### Configure PostgreSQL

```bash
# Create database and user
sudo -u postgres psql -c "CREATE DATABASE streamlite;"
sudo -u postgres psql -c "CREATE USER streamlite WITH ENCRYPTED PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE streamlite TO streamlite;"

# Grant necessary permissions
sudo -u postgres psql -c "ALTER USER streamlite WITH SUPERUSER;"
sudo -u postgres psql -d streamlite -c "GRANT ALL ON SCHEMA public TO streamlite;"
sudo -u postgres psql -d streamlite -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO streamlite;"
sudo -u postgres psql -d streamlite -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO streamlite;"
sudo -u postgres psql -d streamlite -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO streamlite;"
```

### Create Environment File

```bash
# Create .env file
cat > /www/wwwroot/yourdomain.com/.env << EOF
# Database Configuration
DATABASE_URL="postgresql://streamlite:your_password@localhost/streamlite"
PGDATABASE="streamlite"
PGUSER="streamlite"
PGPASSWORD="your_password"
PGHOST="localhost"
PGPORT=5432

# Application Settings
FLASK_APP=app.py
FLASK_ENV=production
SESSION_SECRET="generate_a_random_secret_key_here"
UPLOAD_FOLDER="/www/wwwroot/yourdomain.com/uploads"
ALLOWED_EXTENSIONS=jpg,jpeg,png,mp4,mkv,avi,mov,webm,mp3,ogg,wav
LOG_LEVEL=INFO
EOF

# Set permissions
chmod 600 /www/wwwroot/yourdomain.com/.env
chown www:www /www/wwwroot/yourdomain.com/.env
```

### Create Directories

```bash
# Create uploads directory
mkdir -p /www/wwwroot/yourdomain.com/uploads/thumbnails
chmod -R 777 /www/wwwroot/yourdomain.com/uploads

# Create static error pages
mkdir -p /www/wwwroot/yourdomain.com/static/error_pages
```

### Initialize Database

```bash
# Activate virtual environment
cd /www/wwwroot/yourdomain.com
source venv/bin/activate

# Run initialize script
python initialize.py --non-interactive
```

### Configure Nginx

Edit your Nginx configuration using AaPanel or manually:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Document root
    root /www/wwwroot/yourdomain.com;
    
    # Static files
    location /static {
        alias /www/wwwroot/yourdomain.com/static;
        expires 30d;
        access_log off;
    }
    
    # Uploads
    location /uploads {
        alias /www/wwwroot/yourdomain.com/uploads;
        expires 7d;
    }
    
    # For the 404.html errors
    location = /404.html {
        root /www/wwwroot/yourdomain.com/static/error_pages;
        internal;
    }
    
    # For the robots.txt file
    location = /robots.txt {
        root /www/wwwroot/yourdomain.com/static;
        try_files $uri =404;
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

### Setup Gunicorn Service

```bash
# Create systemd service
cat > /etc/systemd/system/streamlite.service << EOF
[Unit]
Description=StreamLite Gunicorn Daemon
After=network.target

[Service]
User=www
Group=www
WorkingDirectory=/www/wwwroot/yourdomain.com
Environment="PATH=/www/wwwroot/yourdomain.com/venv/bin"
ExecStart=/www/wwwroot/yourdomain.com/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 main:app
Restart=on-failure
RestartSec=5
SyslogIdentifier=streamlite

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
systemctl daemon-reload
systemctl enable streamlite
systemctl start streamlite
```

### Restart Nginx

```bash
/etc/init.d/nginx restart
```

## 2. Common Issues & Quick Fixes

### PostgreSQL Permissions

If you get permission errors:

```bash
# Run the fix_permissions.sh script
sudo -u postgres bash fix_permissions.sh streamlite streamlite

# Or manually
sudo -u postgres psql -c "ALTER USER streamlite WITH SUPERUSER;"
sudo -u postgres psql -d streamlite -c "GRANT ALL ON SCHEMA public TO streamlite;"
```

### Nginx Redirect Loops

If you get redirect loops, update your Nginx configuration:

```nginx
# Comment out any conflicting redirect blocks
# Ensure these proxy headers are set correctly
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Service Won't Start

If the Gunicorn service won't start:

```bash
# Check logs
journalctl -u streamlite

# Verify the venv is working
cd /www/wwwroot/yourdomain.com
source venv/bin/activate
python -c "import flask; print(flask.__version__)"

# Test Gunicorn directly
gunicorn --bind 0.0.0.0:5000 main:app
```

### Missing Static Files

Create necessary static files:

```bash
cat > /www/wwwroot/yourdomain.com/static/robots.txt << EOF
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /user/
Disallow: /login
Disallow: /register
EOF

cat > /www/wwwroot/yourdomain.com/static/error_pages/404.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>404 - Page Not Found</title>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you are looking for does not exist.</p>
    <a href="/">Go back to home</a>
</body>
</html>
EOF
```

### Database Connection Issues

If you can't connect to the database:

```bash
# Check PostgreSQL is running
systemctl status postgresql

# Test direct connection
psql -U streamlite -d streamlite -h localhost

# Update .env with correct credentials
nano /www/wwwroot/yourdomain.com/.env
```

## 3. Verification Steps

### Test the Application

1. Visit your website in a browser
2. Check for error logs:
```bash
tail -f /www/wwwlogs/yourdomain.com.error.log
```

3. Verify Gunicorn logs:
```bash
journalctl -u streamlite -f
```

### Test Database Connection

```bash
cd /www/wwwroot/yourdomain.com
source venv/bin/activate
python -c "from app import db; print(db.engine.table_names())"
```

### Test File Uploads

1. Login to the application and try to upload a media file
2. Check permissions if uploads fail:
```bash
chmod -R 777 /www/wwwroot/yourdomain.com/uploads
```

## 4. Security Considerations

1. After confirming everything works, consider:
   - Removing SUPERUSER privilege from the database user
   - Tightening permissions on upload directories
   - Setting up SSL certificates with Let's Encrypt

2. Configure a firewall:
```bash
# Allow only HTTP, HTTPS, and SSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw enable
```

3. Set secure permissions:
```bash
chmod 600 /www/wwwroot/yourdomain.com/.env
find /www/wwwroot/yourdomain.com -type f -name "*.py" -exec chmod 644 {} \;
```

## 5. Backup and Maintenance

### Regular Backups

1. Database backup:
```bash
mkdir -p /www/backup/streamlite
pg_dump -U postgres -d streamlite | gzip > /www/backup/streamlite/db_$(date +%Y%m%d).sql.gz
```

2. Files backup:
```bash
tar -czf /www/backup/streamlite/files_$(date +%Y%m%d).tar.gz /www/wwwroot/yourdomain.com
```

3. Set up a cron job for regular backups:
```bash
crontab -e
# Add this line for daily backups at 2 AM
0 2 * * * pg_dump -U postgres -d streamlite | gzip > /www/backup/streamlite/db_$(date +\%Y\%m\%d).sql.gz
```

### Maintenance Mode

When doing maintenance:

1. Create a maintenance page:
```bash
cat > /www/wwwroot/yourdomain.com/static/maintenance.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Maintenance</title>
</head>
<body>
    <h1>Site Under Maintenance</h1>
    <p>We're currently performing scheduled maintenance. Please check back shortly.</p>
</body>
</html>
EOF
```

2. Update Nginx to show maintenance page:
```nginx
location / {
    return 503;
}

error_page 503 /maintenance.html;
location = /maintenance.html {
    root /www/wwwroot/yourdomain.com/static;
}
```

3. Restore normal configuration when done.

## 6. Performance Optimization

1. Enable Nginx caching:
```nginx
# Add to Nginx configuration
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
```

2. Increase Gunicorn workers:
```
# Edit ExecStart in streamlite.service
ExecStart=/www/wwwroot/yourdomain.com/venv/bin/gunicorn --workers 8 --bind 0.0.0.0:5000 main:app
```

3. Consider using a CDN for static content.

This quick deploy guide should help you get StreamLite up and running quickly on your VPS environment.