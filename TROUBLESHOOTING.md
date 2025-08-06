# StreamLite Troubleshooting Guide

This document provides solutions for common issues you might encounter when deploying StreamLite on different hosting environments.

## Database Issues

### PostgreSQL Permission Errors

**Problem**: When initializing the database, you encounter errors like:
```
permission denied for schema public
ERROR:  permission denied for schema public
LINE 1: CREATE TABLE user...
```

**Solution**:

1. Run the included `fix_permissions.sh` script as the postgres user or with sudo:
   ```bash
   sudo -u postgres bash fix_permissions.sh
   ```

2. This script grants the necessary permissions to your database user, including:
   - SUPERUSER privileges (or at minimum CREATE permissions)
   - Explicit permissions on the public schema
   - Permissions on all tables, sequences, and functions

3. If running the script doesn't work, manually execute these commands:
   ```sql
   ALTER USER streamlite WITH SUPERUSER;
   GRANT ALL ON SCHEMA public TO streamlite;
   GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO streamlite;
   GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO streamlite;
   GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO streamlite;
   ```

### Database Connection Errors

**Problem**: Unable to connect to the database, seeing errors like:
```
sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) could not connect to server
```

**Solution**:

1. Verify your database credentials in the `.env` file:
   ```
   DATABASE_URL=postgresql://user:password@localhost/database_name
   PGDATABASE=database_name
   PGUSER=username
   PGPASSWORD=password
   PGHOST=localhost
   PGPORT=5432
   ```

2. Ensure PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```

3. Check PostgreSQL connection settings in `pg_hba.conf`:
   ```bash
   # On Debian/Ubuntu
   sudo nano /etc/postgresql/13/main/pg_hba.conf
   
   # On RHEL/CentOS
   sudo nano /var/lib/pgsql/13/data/pg_hba.conf
   ```

4. Add or modify these lines to allow local connections:
   ```
   # IPv4 local connections:
   host    all             all             127.0.0.1/32            md5
   # IPv6 local connections:
   host    all             all             ::1/128                 md5
   ```

## Flask Application Context Errors

**Problem**: Errors related to working outside the Flask application context, like:
```
RuntimeError: Working outside of application context
```

**Solution**:

1. Make sure all database operations in initialize.py are wrapped in an application context:
   ```python
   with app.app_context():
       # Database operations here
   ```

2. The fixed version of `initialize.py` in this repository properly uses application contexts for all database operations.

## Nginx Configuration Issues

### Too Many Redirects Error

**Problem**: Browser shows "ERR_TOO_MANY_REDIRECTS" when trying to access your site.

**Solution**:

1. Use the provided `aapanel_nginx.conf` as a reference for your Nginx configuration.

2. Common causes of redirect loops:
   - Both the application and Nginx are trying to redirect HTTP to HTTPS
   - SSL termination is happening at a load balancer, but Nginx doesn't know this
   - Improper proxy settings are causing the request to loop

3. Key configuration to check:
   ```nginx
   location / {
       proxy_pass http://127.0.0.1:5000;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

### Missing Static Files

**Problem**: 404 errors for static files like robots.txt, 404.html, or CSS/JS files.

**Solution**:

1. Ensure your static files directory is properly configured in Nginx:
   ```nginx
   location /static {
       alias /path/to/your/app/static;
       expires 30d;
       access_log off;
   }
   ```

2. Create the missing files:
   - This repository includes `static/robots.txt` and `static/error_pages/404.html`
   - Make sure these files are accessible in your deployment

## System Service Issues

### Gunicorn Service Not Starting

**Problem**: The StreamLite Gunicorn service fails to start.

**Solution**:

1. Check service status:
   ```bash
   sudo systemctl status streamlite
   ```

2. Check logs for errors:
   ```bash
   sudo journalctl -u streamlite
   ```

3. Verify the service configuration in `/etc/systemd/system/streamlite.service`:
   ```ini
   [Unit]
   Description=StreamLite Gunicorn Daemon
   After=network.target
   
   [Service]
   User=your_user
   Group=your_group
   WorkingDirectory=/path/to/streamlite
   Environment="PATH=/path/to/streamlite/venv/bin"
   ExecStart=/path/to/streamlite/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 main:app
   Restart=on-failure
   RestartSec=5
   
   [Install]
   WantedBy=multi-user.target
   ```

4. Make sure the virtual environment is activated in the service or the full path to binaries is specified.

## Package Installation Issues

### mysqlclient Installation Fails

**Problem**: When trying to install mysqlclient, you get compilation errors.

**Solution**:

1. Install the required development packages:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get install python3-dev default-libmysqlclient-dev build-essential pkg-config
   
   # For RHEL/CentOS
   sudo yum install python3-devel mysql-devel gcc
   ```

2. Then try installing mysqlclient again:
   ```bash
   pip install mysqlclient
   ```

3. Alternatively, use PyMySQL which is a pure Python implementation:
   ```bash
   pip install pymysql
   ```
   
   Then modify your DATABASE_URL to use pymysql:
   ```
   DATABASE_URL=mysql+pymysql://user:password@localhost/dbname
   ```

## Hosting Panel-Specific Issues

### aaPanel Issues

1. Make sure the site directory has correct permissions:
   ```bash
   chown -R www:www /www/wwwroot/yourdomain.com
   ```

2. Verify Python and its modules are properly installed in the virtual environment:
   ```bash
   source /www/wwwroot/yourdomain.com/venv/bin/activate
   pip list
   ```

3. Configure aaPanel's Python Manager to use the correct Python version.

### cPanel Issues

1. Make sure the application uses relative paths that work with cPanel's directory structure.

2. When using cPanel's Python Selector, ensure compatibility with StreamLite's requirements.

3. Use cPanel's built-in PostgreSQL or MySQL database creation tools.

### CyberPanel Issues

1. Check OpenLiteSpeed configuration for proper proxy settings to Gunicorn.

2. Verify the application's virtual environment is properly configured in CyberPanel.

## FFmpeg Issues

**Problem**: Media processing features don't work or thumbnail generation fails.

**Solution**:

1. Verify FFmpeg is installed:
   ```bash
   ffmpeg -version
   ```

2. If not installed, install it:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get install ffmpeg
   
   # For RHEL/CentOS
   sudo yum install epel-release
   sudo yum install ffmpeg ffmpeg-devel
   ```

3. Make sure the StreamLite application has permission to execute FFmpeg.

## Environment Variable Issues

**Problem**: The application can't access environment variables.

**Solution**:

1. Check that the `.env` file exists in the application root directory.

2. Verify the `.env` file has the correct format and permissions:
   ```bash
   cat .env
   chmod 600 .env  # Secure permissions
   ```

3. Make sure the service or process running the application can access the `.env` file.

4. For systemd services, you can also set environment variables directly in the service file:
   ```ini
   [Service]
   Environment="DATABASE_URL=postgresql://user:password@localhost/database"
   Environment="SESSION_SECRET=your_secret_key"
   ```

## Still Having Issues?

If you've tried these solutions and are still experiencing problems:

1. Check the application logs:
   ```bash
   tail -n 100 /path/to/streamlite/logs/gunicorn_error.log
   ```

2. Check the Nginx error logs:
   ```bash
   # For aaPanel
   tail -n 100 /www/wwwlogs/yourdomain.com.error.log
   
   # For standard Nginx
   tail -n 100 /var/log/nginx/error.log
   ```

3. Try running the application directly with Gunicorn to see any errors:
   ```bash
   cd /path/to/streamlite
   source venv/bin/activate
   gunicorn --bind 0.0.0.0:5000 main:app
   ```

4. Consider reinstalling the application with the provided `install.sh` script which handles many common setup issues automatically.