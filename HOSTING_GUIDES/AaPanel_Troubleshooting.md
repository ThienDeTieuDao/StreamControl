# AaPanel Deployment Troubleshooting Guide

This guide addresses common issues that may occur when deploying StreamLite on an AaPanel server.

## Quick Fixes for Common AaPanel Deployment Issues

### 1. PostgreSQL Permission Issues

If you encounter permission errors when initializing the database or when your app tries to create tables:

```
permission denied for schema public
```

**Solution:**

Run the following commands as the PostgreSQL superuser (postgres):

```bash
sudo -u postgres psql

# In the PostgreSQL shell
ALTER USER your_db_user WITH SUPERUSER;
GRANT ALL ON SCHEMA public TO your_db_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_db_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_db_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO your_db_user;
\q
```

Alternatively, use the provided `fix_permissions.sh` script:

```bash
sudo -u postgres bash fix_permissions.sh your_db_name your_db_user
```

### 2. Nginx Redirect Loops

If you get "ERR_TOO_MANY_REDIRECTS" error when accessing your site:

**Solution:**

1. Use the provided `aapanel_nginx.conf` as a reference.
2. Edit your site's Nginx configuration:

```bash
# In aaPanel, use the panel to edit your site's configuration
# Or manually edit it at
nano /www/server/panel/vhost/nginx/yourdomain.com.conf
```

3. Make sure you don't have multiple HTTP to HTTPS redirects. Comment out one of them:

```nginx
# Comment out this if you already have SSL redirect elsewhere
# location / {
#     return 301 https://$server_name$request_uri;
# }
```

4. Ensure proper proxy headers are set:

```nginx
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

5. Restart Nginx:

```bash
/etc/init.d/nginx restart
```

### 3. Missing Static Files or 404 Errors

If Nginx returns 404 for robots.txt, favicon.ico, or other static files:

**Solution:**

1. Create the necessary static files:

```bash
mkdir -p /www/wwwroot/yourdomain.com/static/error_pages
```

2. Create a robots.txt file:

```bash
cat > /www/wwwroot/yourdomain.com/static/robots.txt << EOF
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /user/
Disallow: /login
Disallow: /register
EOF
```

3. Create a 404.html file:

```bash
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

4. Add specific location blocks in your Nginx configuration:

```nginx
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
```

### 4. Python Virtual Environment Issues

If you have problems with the Python virtual environment:

**Solution:**

1. Recreate the virtual environment:

```bash
cd /www/wwwroot/yourdomain.com
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

2. If you get errors about missing Python modules when creating the venv:

```bash
# Install Python development packages
apt-get update
apt-get install python3-dev python3-venv
```

### 5. Gunicorn Service Not Starting

If the Gunicorn service fails to start:

**Solution:**

1. Check Gunicorn service status:

```bash
systemctl status streamlite
```

2. View logs for errors:

```bash
journalctl -u streamlite
```

3. Recreate and restart the service:

```bash
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

systemctl daemon-reload
systemctl restart streamlite
systemctl enable streamlite
```

### 6. Environment Variables Not Working

If the application isn't picking up environment variables:

**Solution:**

1. Check and recreate your `.env` file:

```bash
cat > /www/wwwroot/yourdomain.com/.env << EOF
# Database Configuration
DATABASE_URL="postgresql://your_db_user:your_db_password@localhost/your_db_name"
PGDATABASE="your_db_name"
PGUSER="your_db_user"
PGPASSWORD="your_db_password"
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
```

2. Set proper permissions:

```bash
chmod 600 /www/wwwroot/yourdomain.com/.env
chown www:www /www/wwwroot/yourdomain.com/.env
```

3. Restart the Gunicorn service:

```bash
systemctl restart streamlite
```

### 7. Database Connection Errors

If you encounter database connection errors:

**Solution:**

1. Verify PostgreSQL is running:

```bash
systemctl status postgresql
```

2. Test the connection:

```bash
psql -U your_db_user -d your_db_name -h localhost
```

3. Check PostgreSQL configuration:

```bash
# Edit PostgreSQL connection settings
nano /var/lib/pgsql/13/data/pg_hba.conf
# or on Debian-based systems
nano /etc/postgresql/13/main/pg_hba.conf
```

4. Make sure you have these lines for local connections:

```
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
```

5. Restart PostgreSQL:

```bash
systemctl restart postgresql
```

### 8. Permissions and File Access Issues

If you encounter file access errors:

**Solution:**

1. Set the correct ownership for all files:

```bash
chown -R www:www /www/wwwroot/yourdomain.com
```

2. Set proper permissions:

```bash
chmod -R 755 /www/wwwroot/yourdomain.com
chmod -R 777 /www/wwwroot/yourdomain.com/uploads  # More permissive for uploads
chmod 600 /www/wwwroot/yourdomain.com/.env  # Restrictive for env file
```

### 9. Missing Libraries for mysqlclient

If you choose to use MySQL and encounter errors installing mysqlclient:

**Solution:**

1. Install required development libraries:

```bash
apt-get update
apt-get install python3-dev default-libmysqlclient-dev build-essential pkg-config
```

2. Then reinstall mysqlclient:

```bash
source /www/wwwroot/yourdomain.com/venv/bin/activate
pip install mysqlclient
```

### 10. Testing and Debugging

To test your application directly:

```bash
cd /www/wwwroot/yourdomain.com
source venv/bin/activate
gunicorn --bind 0.0.0.0:5000 main:app
```

To check for errors in real-time:

```bash
tail -f /www/wwwroot/yourdomain.com/logs/gunicorn_error.log
```

Check Nginx access and error logs:

```bash
tail -f /www/wwwlogs/yourdomain.com.access.log
tail -f /www/wwwlogs/yourdomain.com.error.log
```

## Complete Reinstallation Process

If you need to start fresh, here's a complete reinstallation process for aaPanel:

```bash
# 1. Stop and remove the existing service
systemctl stop streamlite
systemctl disable streamlite
rm /etc/systemd/system/streamlite.service

# 2. Clear out the existing application
rm -rf /www/wwwroot/yourdomain.com/*

# 3. Clone or upload the new application files
cp -R /path/to/streamlite/* /www/wwwroot/yourdomain.com/

# 4. Set proper ownership
chown -R www:www /www/wwwroot/yourdomain.com

# 5. Create and configure the virtual environment
cd /www/wwwroot/yourdomain.com
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 6. Set up the database (if using PostgreSQL)
sudo -u postgres psql -c "CREATE DATABASE streamlite;"
sudo -u postgres psql -c "CREATE USER streamlite WITH ENCRYPTED PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE streamlite TO streamlite;"
sudo -u postgres psql -c "ALTER USER streamlite WITH SUPERUSER;"
sudo -u postgres psql -d streamlite -c "GRANT ALL ON SCHEMA public TO streamlite;"

# 7. Create the .env file
cat > .env << EOF
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

# 8. Set proper permissions
chmod 600 .env
mkdir -p uploads/thumbnails
chmod -R 777 uploads

# 9. Initialize the database
python initialize.py --non-interactive

# 10. Create the systemd service file
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

# 11. Enable and start the service
systemctl daemon-reload
systemctl enable streamlite
systemctl start streamlite

# 12. Create necessary static files
mkdir -p static/error_pages
cat > static/robots.txt << EOF
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /user/
Disallow: /login
Disallow: /register
EOF

cat > static/error_pages/404.html << EOF
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

# 13. Update aaPanel Nginx configuration through the panel or manually
# Then restart Nginx
/etc/init.d/nginx restart
```

## Additional AaPanel-Specific Tips

1. **Securing Your Installation**:
   - Use AaPanel's firewall to restrict access to port 5000 (Gunicorn)
   - Consider using Let's Encrypt SSL within AaPanel for HTTPS

2. **Database Management**:
   - Use AaPanel's PostgreSQL Manager or MySQL Manager for GUI-based database management
   - Regular backups via AaPanel's backup system

3. **Monitoring**:
   - Set up site monitoring in AaPanel
   - Consider installing the AaPanel monitoring plugin for additional metrics

4. **Performance Optimization**:
   - Install and configure Redis for caching
   - Use AaPanel's CDN features for static content delivery

By following this troubleshooting guide, you should be able to resolve most common issues encountered when deploying StreamLite on AaPanel.